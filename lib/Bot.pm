package Bot;

use v5.40;

use Mooish::Base;
use Mojo::UserAgent;
use Mojo::Template;
use Mojo::Promise;

use Bot::Log;
use Bot::Notes;
use Bot::Context;
use Bot::Conversation;
use Bot::Conversation::Config;
use all 'Bot::AITool';
use all 'Bot::Command';

has param 'environment' => (
	isa => SimpleStr,
);

has param 'config' => (
	coerce => (InstanceOf ['Bot::Conversation::Config'])->plus_coercions(
		HashRef, q{ Bot::Conversation::Config->new($_) },
	),
	default => sub { {} },
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
			Bot::Command::Personality->register($self),
			Bot::Command::Chat->register($self),
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

sub _system_prompts ($self, $ctx)
{
	state $template = Mojo::Template->new(vars => 1);
	my @prompts;

	push @prompts, $template->render_file(
		"prompts/personality.@{[$ctx->config->personality]}.ep", {
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

sub _add_ai_query ($self, $ctx)
{
	$self->get_conversation($ctx)->add_message('user', $ctx->message);
}

sub _add_ai_response ($self, $ctx)
{
	$self->get_conversation($ctx)->add_message('assistant', $ctx->response);
}

sub _handle_command ($self, $ctx)
{
	my $prefix = quotemeta Bot::Command->prefix;

	my $msg = $ctx->message;
	my @commands;

	while ($msg =~ s{^\s*$prefix(\w+)(?:\((.+)\))?}{}) {
		my $command = $1;
		my @args = grep { defined } split /\s+/, $2 // '';

		if ($self->commands->{$command}) {
			push @commands, [$self->commands->{$command}, \@args];
		}
		else {
			$ctx->set_response("Unknown command $command");
			return !!1;
		}
	}

	return !!0 if !@commands;

	$msg = trim($msg);
	my $altering = length $msg > 0;
	$ctx->set_message($msg) if $altering;

	my @output;
	foreach my $command (@commands) {
		try {
			if ($altering) {
				if (!$command->[0]->can_alter) {
					$ctx->set_response("Command @{[$command->[0]->name]} cannot alter a message");
					return !!1;
				}

				$command->[0]->alter($ctx, $command->[1]->@*);
			}
			else {
				push @output, $command->[0]->run($ctx, $command->[1]->@*);
			}
		}
		catch ($e) {
			my $hint = '';
			if (ref $e eq 'HASH' && $e->{hint}) {
				$hint = ": $e->{hint}";
			}
			else {
				$self->log->debug($e);
			}

			$ctx->set_response("Command error$hint. Usage: " . $command->[0]->get_usage);
		}
	}

	$ctx->set_response(join "\n", @output) if @output;
	return $ctx->has_response;
}

sub _finalize_ai_reply ($self, $ctx, $reason, $reply)
{
	if ($reason eq 'tool_use') {
		$self->requery($ctx);
	}
	else {
		$ctx->set_response($reply);
		$self->_add_ai_response($ctx);
	}
}

sub _process_query_data ($self, $ctx, $json)
{
	my $reply;
	my @promises;
	foreach my $res_data ($json->{content}->@*) {
		if ($res_data->{type} eq 'text') {
			$reply = $res_data->{text};
		}
		elsif ($res_data->{type} eq 'tool_use') {
			push @promises, $self->use_tool($ctx, $res_data) // ();
		}
	}

	my $fulfill = sub { $self->_finalize_ai_reply($ctx, $json->{stop_reason}, $reply) };
	if (@promises) {
		Mojo::Promise->all(@promises)->finally($fulfill);
	}
	else {
		$fulfill->();
	}
}

sub _can_use_ai ($self, $ctx)
{
	return $ctx->has_channel || $ctx->user_of($self->trusted_users);
}

sub get_context ($self, @params)
{
	my $ctx = Bot::Context->new(@params);
	$ctx->set_config($self->get_conversation($ctx)->config->clone);
	return $ctx;
}

sub get_conversation ($self, $ctx)
{
	my $conv = $self->conversations->{$ctx->user} //= Bot::Conversation->new(
		config => $self->config->clone,
		conversation_lifetime => $self->conversation_lifetime,
	);

	$conv->clear if $conv->expired;
	return $conv;
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
				add_tool_result('Tool error occured');
			}
		);

		return $result;
	}
	else {
		add_tool_result($result);
		return undef;
	}
}

sub _query ($self, $ctx)
{
	return Mojo::Promise->resolve if $ctx->has_response;
	return $self->ua->post_p(
		'https://api.anthropic.com/v1/messages',
		{
			'x-api-key' => $self->claude_config->{api_key},
			'anthropic-version' => '2023-06-01',
		},
		json => {
			model => $self->claude_config->{model},
			max_tokens => 1_000,
			system => $self->_system_prompts($ctx),
			messages => $self->get_conversation($ctx)->api_call_format_messages,
			tool_choice => {type => 'auto'},
			tools => [
				map { $_->definition } grep { $_->available($ctx) } values $self->tools->%*
			],
		},
	)->then(
		sub ($tx) {
			my $res = $tx->result;
			if (!$res->is_success) {
				$self->log->error('AI query HTTP error: ' . $res->text);
				die {retry => !!1};
			}

			try {
				$self->_process_query_data($ctx, $res->json);
			}
			catch ($e) {
				$self->log->error("AI query fatal error: $e");
				die {retry => !!0};
			}
		},
		sub (@err) {
			$self->log->error("AI query connection error: @err");
			return {retry => !!0};
		}
	);
}

sub add_message ($self, $ctx)
{
	my $msgs = $self->observed_messages->{$ctx->channel_text} //= [];
	push @$msgs, [$ctx->user, $ctx->message];

	splice @$msgs, 0, -1 * $self->config->history_size;
}

sub query ($self, $ctx)
{
	if ($self->_handle_command($ctx)) {
		return;
	}

	$self->_add_ai_query($ctx);

	if (!$self->_can_use_ai($ctx)) {
		my $user = $ctx->user;
		my $owner = $self->owner;
		$self->log->info("User $user got refused the private use of AI");
		$ctx->set_response(
			qq{I'm sorry, but your name "$user" is not allowed to use my AI in a private chat. Ask "$owner" to add you to trusted users.}
		);

		return;
	}

	$self->requery($ctx);
}

sub requery ($self, $ctx)
{
	$self->_query($ctx)->then(
		undef,
		sub ($status) {
			$ctx->failure($status);
			$self->requery($ctx);
		}
	);
}

