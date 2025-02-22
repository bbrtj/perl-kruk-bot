package Bot;

use v5.40;

use Mooish::Base;
use Mojo::UserAgent;
use Mojo::Template;
use Data::Dumper;

use Bot::Notes;
use all 'Bot::AITool';
use all 'Bot::Command';

has param 'personality' => (
	isa => SimpleStr,
	default => 'default',
);

has field 'claude_config' => (
	isa => HashRef,
	default => sub {
		return {
			api_key => $ENV{KRUK_CLAUDE_API_KEY},
			model => $ENV{KRUK_CLAUDE_MODEL},
		};
	},
);

has param 'history_size' => (
	isa => PositiveInt,
	default => 25,
);

has param 'owner' => (
	isa => SimpleStr,
	default => $ENV{KRUK_OWNER},
);

has param 'trusted_users' => (
	isa => ArrayRef,
	default => sub {
		[split /,/, $ENV{KRUK_TRUSTED_USERS}]
	}
);

has field 'observed_messages' => (
	isa => HashRef [ArrayRef [Tuple [Str, Str]]],
	default => sub { {} },
);

has field 'conversations' => (
	isa => HashRef [Tuple [Str, Str | Object]],
	default => sub { {} },
);

has field 'tools' => (
	isa => HashRef [InstanceOf ['Bot::AITool']],
	default => sub ($self) {
		return {
			Bot::AITool::ReadChat->register($self),
			Bot::AITool::SaveSelfNote->register($self),
			Bot::AITool::SaveUserNote->register($self),
		};
	},
);

has field 'commands' => (
	isa => HashRef [InstanceOf ['Bot::Command']],
	default => sub ($self) {
		return {
			Bot::Command::MyNotes->register($self),
			Bot::Command::Notes->register($self),
		};
	},
);

has field 'self_notes' => (
	isa => InstanceOf ['Bot::Notes'],
	default => sub {
		Bot::Notes->new(context => 'self');
	},
);

has field 'user_notes' => (
	isa => InstanceOf ['Bot::Notes'],
	default => sub {
		Bot::Notes->new(context => 'user');
	},
);

has field 'ua' => (
	isa => InstanceOf ['Mojo::UserAgent'],
	default => sub {
		Mojo::UserAgent->new;
	},
);

sub system_text ($self, $ctx)
{
	state $template = Mojo::Template->new(vars => 1);
	my $personality = $self->personality;
	my $system_prompt = $template->render_file(
		"system.$personality.ep", {
			bot => $self,
			ctx => $ctx,
		}
	);

	return $system_prompt;
}

sub add_message ($self, $ctx)
{
	my $msgs = $self->observed_messages->{$ctx->channel_text} //= [];
	push @$msgs, [$ctx->user, $ctx->message];

	splice @$msgs, 0, -1 * $self->history_size;
}

sub add_bot_query ($self, $ctx)
{
	my $convs = $self->conversations->{$ctx->user} //= [];
	if (@$convs && $convs->[-1][0] eq 'user') {
		if (ref $convs->[-1][1] ne 'ARRAY') {
			$convs->[-1][1] = [$convs->[-1][1]];
		}
		push $convs->[-1][1]->@*, $ctx->message;
	}
	else {
		push @$convs, ['user', $ctx->message];
	}

	splice @$convs, 0, -1 * $self->history_size * 2;
}

sub add_bot_response ($self, $ctx)
{
	push $self->conversations->{$ctx->user}->@*, ['assistant', $ctx->response];
}

sub use_tool ($self, $ctx, $tool_data)
{
	die "Undefined tool $tool_data->{name}"
		unless $self->tools->{$tool_data->{name}};

	my $result = $self->tools->{$tool_data->{name}}->runner($ctx, $tool_data->{input});

	push $self->conversations->{$ctx->user}->@*, ['assistant', [$tool_data]];
	push $self->conversations->{$ctx->user}->@*, [
		'user', [
			{
				type => 'tool_result',
				tool_use_id => $tool_data->{id},
				content => $result,
			}
		]
	];
}

sub handle_command ($self, $ctx)
{
	my $prefix = quotemeta Bot::Command->prefix;
	if ($ctx->message =~ m{^\s*$prefix(\w+)(?: (.+))?$}) {
		my $command = $1;
		my @args = split /\s+/, $2 // '';

		if ($self->commands->{$command}) {
			try {
				$ctx->set_response($self->commands->{$command}->runner($ctx, @args));
			}
			catch ($e) {
				say $e;
				$ctx->set_response('Command error. Usage: ' . $self->commands->{$command}->get_usage);
			}
		}
		else {
			$ctx->set_response('Unknown command');
		}

		return !!1;
	}

	return !!0;
}

sub query_bot ($self, $ctx)
{
	if (!$ctx->has_channel && !$ctx->user_of($self->trusted_users)) {
		my $user = $ctx->user;
		my $owner = $self->owner;
		$ctx->set_response(
			qq{I'm sorry, but your name "$user" is not allowed to use my AI in a private chat. Ask "$owner" to add you to trusted users.}
		);
		return;
	}

	$self->ua->post_p(
		'https://api.anthropic.com/v1/messages',
		{
			'x-api-key' => $self->claude_config->{api_key},
			'anthropic-version' => '2023-06-01',
		},
		json => {
			model => $self->claude_config->{model},
			max_tokens => 1_000,
			system => $self->system_text($ctx),
			messages => [
				(
					map {
						+{
							role => $_->[0],
							content => $_->[1],
						}
					} $self->conversations->{$ctx->user}->@*
				),
			],
			tool_choice => {type => 'auto'},
			tools => [
				map { $_->definition } grep { $_->available($ctx) } values $self->tools->%*
			],
		},
	)->then(
		sub ($tx) {
			my $res = $tx->result;
			die Dumper(['API error', $res])
				unless $res->is_success;

			my $reply;
			foreach my $res_data ($res->json->{content}->@*) {
				if ($res_data->{type} eq 'text') {
					$reply = $res_data->{text};
				}
				elsif ($res_data->{type} eq 'tool_use') {
					$self->use_tool($ctx, $res_data);
				}
			}

			if ($res->json->{stop_reason} eq 'tool_use') {

				# TODO: wait until tools are finished?
				$self->query_bot($ctx);
			}
			else {
				$ctx->set_response($reply);
				$self->add_bot_response($ctx);
			}
		}
	);

	return;
}

