package Bot;

use v5.40;

use Mooish::Base;
use Mojo::UserAgent;
use Mojo::Template;
use Mojo::Promise;
use Mojo::IOLoop;
use List::Util qw(any);
use Regexp::Common qw(RE_ALL);

use Kruk;
use Bot::I18N;
use Bot::Log;
use Bot::Notes;
use Bot::Cache;
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

has field 'claude_api_key' => (
	isa => Maybe [SimpleStr],
	default => sub {
		$ENV{KRUK_CLAUDE_API_KEY};
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
			Bot::Command::Sudo->register($self),
			Bot::Command::Calc->register($self),
			Bot::Command::Timer->register($self),
		};
	},
);

has field 'notes' => (
	isa => InstanceOf ['Bot::Notes'],
	default => sub {
		Bot::Notes->new;
	},
);

has field 'cache' => (
	isa => InstanceOf ['Bot::Cache'],
	default => sub ($self) {
		Bot::Cache->new(bot_instance => $self);
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
		Bot::Log->singleton;
	},
);

has field 'context_sub' => (
	isa => CodeRef,
	writer => 'on_new_context',
);

sub _make_text ($self, $text)
{
	return {
		type => 'text',
		text => $text,
	};
}

sub _system_prompts ($self, $ctx)
{
	state $template = Mojo::Template->new(vars => 1);
	my @prompts;
	my %params;
	my $set_param = sub ($key, $value) { $params{$key} = $value };

	push @prompts, $template->render_file(
		Kruk->root_dir->child("prompts/personality.@{[$ctx->config->personality]}.ep"), {
			bot => $self,
			ctx => $ctx,
			set_param => $set_param,
		}
	);

	try {
		push @prompts, $template->render_file(
			Kruk->root_dir->child("prompts/environment.@{[$self->environment]}.ep"), {
				bot => $self,
				ctx => $ctx,
				set_param => $set_param,
			}
		);
	}
	catch ($e) {
		die $e if $e !~ /no such file or directory/i;
	}

	push @prompts, grep { length }
		$self->notes->dump(prefix => 'Here is your diary:'),
		$self->notes->dump(aspect => $ctx->user, prefix => 'Here are your notes about the user:');

	@prompts = map { $self->_make_text($_) } @prompts;
	$params{system} = \@prompts;
	return %params;
}

sub _lock_context ($self, $ctx)
{
	my $conv = $self->get_conversation($ctx);
	return !!0 if $conv->locked;

	$conv->lock;
	$ctx->promise->finally(sub { $conv->unlock });
	return !!1;
}

sub _add_ai_query ($self, $ctx)
{
	$self->get_conversation($ctx)->add_message('user', $ctx->message);
}

sub _add_ai_response ($self, $ctx)
{
	$self->get_conversation($ctx)->add_message('assistant', $ctx->response);
}

sub _handle_command ($self, $ctx, $command, $args_string, $altering)
{
	$args_string = substr $args_string, 1, -1
		if defined $args_string && $altering;

	my @args = grep { defined } split /\s+/, $args_string // '';

	if ($self->commands->{$command}) {
		$self->commands->{$command}->execute($ctx, \@args, $altering);
	}
	else {
		$ctx->set_response(_t 'err.unknown_command', $command);
	}
}

sub _handle_commands ($self, $ctx)
{
	state $prefix = quotemeta Bot::Command->prefix;
	state $alter_prefix = quotemeta Bot::Command->alter_prefix;
	state $balanced_parens_re = RE_balanced(-parens => '()');

	my $msg = $ctx->message;
	my $altered_times = 0;
	while ($msg =~ s{^\s*$alter_prefix(\w+)($balanced_parens_re)?}{}) {
		next if $ctx->has_response;
		$self->_handle_command($ctx, $1, $2, !!1);
		++$altered_times;
	}

	$msg = trim($msg);
	$ctx->set_message($msg);

	# special help message
	if (!$ctx->has_response && any { $msg eq $_ } '', 'help') {
		$ctx->set_response(_t 'help', Bot::Command->prefix);
	}

	if (!$ctx->has_response && $msg =~ m{^\s*$prefix(\w+)(?:\s+(.+))?$}) {
		$self->_handle_command($ctx, $1, $2, !!0);
	}

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
			$self->log->info("partial response: $reply")
				if defined $reply;
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
	return defined $self->claude_api_key && ($ctx->has_channel || $ctx->user_of($self->trusted_users));
}

sub get_context ($self, @params)
{
	my $ctx = Bot::Context->new(@params);
	$ctx->set_config($self->get_conversation($ctx)->config->clone);

	if (my $hook = $self->context_sub) {
		$hook->($ctx);
	}

	return $ctx;
}

sub get_conversation ($self, $ctx)
{
	my $key = sprintf '%s -> %s', $ctx->channel // '', $ctx->user;
	my $conv = $self->conversations->{$key} //= Bot::Conversation->new(
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
						$self->_make_text($result)
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

	my $data = {
		$self->_system_prompts($ctx),
		max_tokens => 2048,
		messages => $self->get_conversation($ctx)->api_call_format_messages,
		tool_choice => {type => 'auto'},
		tools => [
			map { $_->definition } grep { $_->available($ctx) } values $self->tools->%*
		],
	};

	my $cached_data = $self->cache->process_cache($ctx, $data);

	return $self->ua->post_p(
		'https://api.anthropic.com/v1/messages',
		{
			'x-api-key' => $self->claude_api_key,
			'anthropic-version' => '2023-06-01',
		},
		json => $data
	)->then(
		sub ($tx) {
			my $res = $tx->result;
			if (!$res->is_success) {
				$self->log->error('AI query HTTP error: ' . $res->text);
				die {retry => !!1};
			}

			my $json = $res->json;
			$self->log->debug(
				sprintf(
					'Input tokens expected/actual (cache read/write): %s/%s (%s/%s), %s cache breakpoints',
					$cached_data->{expected_tokens},
					$json->{usage}->@{qw(input_tokens cache_read_input_tokens cache_creation_input_tokens)},
					$cached_data->{breakpoints},
				)
			);

			$self->get_conversation($ctx)->set_cached
				if $cached_data->{messages_cached} && $json->{usage}{cache_creation_input_tokens} > 0;

			try {
				$self->_process_query_data($ctx, $json);
			}
			catch ($e) {
				$self->log->error("AI query fatal error: $e");
				die {retry => !!0};
			}
		},
		sub (@err) {
			$self->log->error("AI query connection error: @err");
			die {retry => !!0};
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
	return if $self->_handle_commands($ctx);

	if (!$self->_can_use_ai($ctx)) {
		$self->log->info("User @{[$ctx->user]} got refused the use of AI");
		$ctx->set_response(_t 'err.ai_use_refused');

		return;
	}

	if (!$self->_lock_context($ctx)) {
		$ctx->set_response(_t 'err.ai_already_queried');

		return;
	}

	$self->_add_ai_query($ctx);
	$self->requery($ctx);
}

sub requery ($self, $ctx)
{
	$self->_query($ctx)->then(
		undef,
		sub ($status) {
			$ctx->failure(%$status);
			Mojo::IOLoop->timer(($ctx->retries**2) * 2, sub { $self->requery($ctx) })
				unless $ctx->has_response;
		}
	);
}

