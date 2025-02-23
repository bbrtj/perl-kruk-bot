package Bot;

use v5.40;

use Mooish::Base;
use Mojo::UserAgent;
use Mojo::Template;
use Mojo::Promise;
use Data::Dumper;

use Bot::Log;
use Bot::Notes;
use Bot::Conversation;
use all 'Bot::AITool';
use all 'Bot::Command';

has param 'environment' => (
	isa => SimpleStr,
);

has param 'personality' => (
	isa => SimpleStr,
	default => 'default',
);

has param 'history_size' => (
	isa => PositiveInt,
	default => 25,
);

has param 'conversation_lifetime' => (
	isa => PositiveInt,
	default => sub { $ENV{KRUK_CONVERSATION_LIFETIME} // 120 },
);

has param 'owner' => (
	isa => SimpleStr,
	default => $ENV{KRUK_OWNER} // 'user',
);

has param 'trusted_users' => (
	isa => ArrayRef,
	lazy => sub ($self) {
		[split /,/, $ENV{KRUK_TRUSTED_USERS} // $self->owner]
	}
);

has field 'claude_config' => (
	isa => HashRef,
	default => sub {
		return {
			api_key => $ENV{KRUK_CLAUDE_API_KEY},
			model => $ENV{KRUK_CLAUDE_MODEL},
			cache_length => $ENV{KRUK_CLAUDE_CACHE_LENGTH} // 4000,
		};
	},
);

has field 'observed_messages' => (
	isa => HashRef [ArrayRef [Tuple [Str, Str]]],
	default => sub { {} },
);

has field 'conversations' => (
	isa => HashRef [InstanceOf ['Bot::Conversation']],
	default => sub { {} },
);

has field 'tools' => (
	isa => HashRef [InstanceOf ['Bot::AITool']],
	default => sub ($self) {
		return {
			Bot::AITool::ReadChat->register($self),
			Bot::AITool::SaveSelfNote->register($self),
			Bot::AITool::SaveUserNote->register($self),
			Bot::AITool::FetchWebpage->register($self),
		};
	},
);

has field 'commands' => (
	isa => HashRef [InstanceOf ['Bot::Command']],
	default => sub ($self) {
		return {
			Bot::Command::Help->register($self),
			Bot::Command::MyNotes->register($self),
			Bot::Command::Notes->register($self),
		};
	},
);

has field 'notes' => (
	isa => InstanceOf ['Bot::Notes'],
	default => sub {
		Bot::Notes->new;
	},
);

has field 'ua' => (
	isa => InstanceOf ['Mojo::UserAgent'],
	default => sub {
		Mojo::UserAgent->new;
	},
);

has field 'log' => (
	isa => InstanceOf ['Bot::Log'],
	default => sub {
		Bot::Log->new(filename => 'bot.log');
	},
);

sub _make_text_with_caching ($self, $text)
{
	my $should_cache = length $text > $self->claude_config->{cache_length};
	$self->log->debug('Requesting caching of text: ' . (length $text) . ' characters')
		if $should_cache;

	return {
		type => 'text',
		text => $text,
		($should_cache ? (cache_control => {type => 'ephemeral'}) : ()),
	};
}

sub get_conversation ($self, $ctx)
{
	my $conv = $self->conversations->{$ctx->user} //= Bot::Conversation->new(
		personality => $self->personality,
		history_size => $self->history_size,
		conversation_lifetime => $self->conversation_lifetime,
	);

	$conv->clear if $conv->expired;
	return $conv;
}

sub system_prompts ($self, $ctx)
{
	state $template = Mojo::Template->new(vars => 1);
	my @prompts;

	push @prompts, $template->render_file(
		"prompts/personality.@{[$self->personality]}.ep", {
			bot => $self,
			ctx => $ctx,
		}
	);

	try {
		push @prompts, $template->render_file(
			"prompts/environment.@{[$self->environment]}.ep", {
				bot => $self,
				ctx => $ctx,
			}
		);
	}
	catch ($e) {
		die $e if $e !~ /no such file or directory/i;
	}

	push @prompts, grep { length }
		$self->notes->dump(prefix => 'Here is your diary:'),
		$self->notes->dump(aspect => $ctx->user, prefix => 'Here are your notes about the user:');

	@prompts = map { $self->_make_text_with_caching($_) } @prompts;
	return \@prompts;
}

sub add_message ($self, $ctx)
{
	my $msgs = $self->observed_messages->{$ctx->channel_text} //= [];
	push @$msgs, [$ctx->user, $ctx->message];

	splice @$msgs, 0, -1 * $self->history_size;
}

sub add_bot_query ($self, $ctx)
{
	$self->get_conversation($ctx)->add_message('user', $ctx->message);
}

sub add_bot_response ($self, $ctx)
{
	$self->get_conversation($ctx)->add_message('assistant', $ctx->response);
}

sub use_tool ($self, $ctx, $tool_data)
{
	die "Undefined tool $tool_data->{name}"
		unless $self->tools->{$tool_data->{name}};

	$self->log->debug("Using AI tool $tool_data->{name}");
	my $result = $self->tools->{$tool_data->{name}}->runner($ctx, $tool_data->{input});

	my sub add_tool_result ($result)
	{
		$self->get_conversation($ctx)
			->add_message('assistant', $tool_data)
			->add_message(
				'user', {
					type => 'tool_result',
					tool_use_id => $tool_data->{id},
					content => [
						$self->_make_text_with_caching($result)
					],
				}
			);
	}

	if ($result isa 'Mojo::Promise') {
		$result->then(
			sub (@data) {
				add_tool_result(join "\n", @data);
			},
			sub (@errors) {
				$self->log->error("Tool $tool_data->{name} usage failed: @errors");
				add_tool_result("Tool error occured: @errors");
			}
		);

		return $result;
	}
	else {
		add_tool_result($result);
		return undef;
	}
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
		$self->log->notice("User $user got refused the private use of AI");
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
			system => $self->system_prompts($ctx),
			messages => $self->get_conversation($ctx)->api_call_format_messages,
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
			my @promises;
			foreach my $res_data ($res->json->{content}->@*) {
				if ($res_data->{type} eq 'text') {
					$reply = $res_data->{text};
				}
				elsif ($res_data->{type} eq 'tool_use') {
					push @promises, $self->use_tool($ctx, $res_data);
				}
			}

			@promises = grep { defined } @promises;

			my sub fulfill
			{
				if ($res->json->{stop_reason} eq 'tool_use') {
					$self->query_bot($ctx);
				}
				else {
					$ctx->set_response($reply);
					$self->add_bot_response($ctx);
				}
			}

			if (@promises) {
				Mojo::Promise->all(@promises)->finally(\&fulfill);
			}
			else {
				fulfill;
			}
		},
		sub (@err) {
			$self->log->error("Failed AI query: @err");
		}
	)->catch(
		sub (@err) {
			$self->log->error("AI query handler error: @err");
		}
	);

	return;
}

