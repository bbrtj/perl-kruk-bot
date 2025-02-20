package Bot;

use v5.40;

use Moo;
use Mooish::AttributeBuilder;
use Types::Standard -types;
use Mojo::UserAgent;
use Mojo::Template;
use Data::Dumper;

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

has field 'observed_messages' => (
	isa => HashRef [ArrayRef [Tuple [Str, Str]]],
	default => sub { {} },
);

has field 'conversations' => (
	isa => HashRef [Tuple [Str, Str | Object]],
	default => sub { {} },
);

has field 'ua' => (
	isa => InstanceOf ['Mojo::UserAgent'],
	default => sub {
		Mojo::UserAgent->new;
	},
);

sub system_text ($self, $channel, $user)
{
	state $template = Mojo::Template->new(vars => 1);
	$channel //= $user;
	my $system_prompt = $template->render_file('system.tpl', {
		bot => $self,
		channel => $channel,
		user => $user,
	});

	return $system_prompt;
}

sub add_message ($self, $channel, $user, $message)
{
	$channel //= $user;
	my $msgs = $self->observed_messages->{$channel} //= [];
	push @$msgs, [$user, $message];

	splice @$msgs, 0, -1 * $self->history_size;
}

sub add_bot_query ($self, $user, $message)
{
	my $convs = $self->conversations->{$user} //= [];
	if (@$convs && $convs->[-1][0] eq 'user' && !ref $convs->[-1][1]) {
		$convs->[-1][1] .= "\n$message";
	}
	else {
		push @$convs, ['user', $message];
	}

	splice @$convs, 0, -1 * $self->history_size * 2;
}

sub add_bot_response ($self, $user, $message)
{
	push $self->conversations->{$user}->@*, ['assistant', $message];
}

my %tools = (
	get_messages => {
		definition => {
			name => 'get_messages',
			description  => q{Get everyone's messages in this chat room. To avoid privacy breach, DO NOT USE unless the user typed word "sudo".},
			input_schema => {
				type => 'object',
			},
		},
		runner => sub ($self, $channel, $user, $input) {
			return join "\n",
				map { "$_->[0] said: $_->[1]" }
				$self->observed_messages->{$channel}->@*;
		},
	},
);

sub use_tool ($self, $channel, $user, $tool_data)
{
	die "Undefined tool $tool_data->{name}"
		unless $tools{$tool_data->{name}};

	my $result = $tools{$tool_data->{name}}{runner}->($self, $channel, $user, $tool_data->{input});

	push $self->conversations->{$user}->@*, ['assistant', [$tool_data]];
	push $self->conversations->{$user}->@*, ['user', [{
		type => 'tool_result',
		tool_use_id => $tool_data->{id},
		content => $result,
	}]];
}

sub query_ai ($self, $channel, $user, $ret_sub)
{
	$channel //= $user;
	$self->ua->post_p(
		'https://api.anthropic.com/v1/messages',
		{
			'x-api-key' => $self->claude_config->{api_key},
			'anthropic-version' => '2023-06-01',
		},
		json => {
			model => $self->claude_config->{model},
			max_tokens => 1_000,
			system => $self->system_text($channel, $user),
			messages => [
				(map {
					+{
						role => $_->[0],
						content => $_->[1],
					}
				} $self->conversations->{$user}->@*),
			],
			tool_choice => { type => 'auto' },
			tools => [
				map { $tools{$_}{definition} } sort keys %tools
			],
		},
	)->then(sub ($tx) {
		my $res = $tx->result;
		die Dumper(['API error', $res])
			unless $res->is_success;

		my $reply;
		foreach my $res_data ($res->json->{content}->@*) {
			if ($res_data->{type} eq 'text') {
				$reply = $res_data->{text};
			}
			elsif ($res_data->{type} eq 'tool_use') {
				$self->use_tool($channel, $user, $res_data);
			}
		}

		if ($res->json->{stop_reason} eq 'tool_use') {
			# TODO: wait until tools are finished?
			$self->query_ai($channel, $user, $ret_sub);
		}
		else {
			$self->add_bot_response($user, $reply);
			$ret_sub->($reply);
		}
	});

	return;
}

