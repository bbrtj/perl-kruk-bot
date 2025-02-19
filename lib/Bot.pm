package Bot;

use v5.40;

use Moo;
use Mooish::AttributeBuilder;
use Types::Standard -types;
use Mojo::Redis;
use Mojo::UserAgent;

has field 'claude_config' => (
	isa => HashRef,
	default => sub {
		return {
			api_key => $ENV{KRUK_CLAUDE_API_KEY},
			model => $ENV{KRUK_CLAUDE_MODEL},
		};
	},
);

has param 'redis' => (
	isa => InstanceOf['Mojo::Redis'],
	default => sub { Mojo::Redis->new('redis://127.0.0.1:6379/kruk') },
);

has field 'observed_messages' => (
	isa => HashRef [ArrayRef [Tuple [Str, Str]]],
	default => sub { {} },
);

has field 'conversations' => (
	isa => HashRef [Tuple [Str, Str]],
	default => sub { {} },
);

has field 'ua' => (
	isa => InstanceOf ['Mojo::UserAgent'],
	default => sub {
		Mojo::UserAgent->new;
	},
);

sub system_text ($self, $user)
{
	return <<~TEXT;
	You are a chatbot. Your name is Kruk. You are named like that since you bring wisdom.
	You are to keep your responses short, since you may be used in scenarios where messages are confined to a couple hundred characters.
	You are currently talking to "$user". The user will know that you are talking to him. If you want to mention other people, you must do so explicitly.
	You specialize in following topics: Perl, Pascal, Bitcoin. You present yourself as an expert and a fan of those.
	TEXT
}

sub add_message ($self, $channel, $user, $message)
{
	use Data::Dumper; warn Dumper(['add_message', $channel, $user, $message]);
	$channel //= $user;
	my $msgs = $self->observed_messages->{$channel} //= [];
	my $convs = $self->conversations->{$user} //= [];
	push @$msgs, [$user, $message];
	if (@$convs && $convs->[-1][0] eq 'user') {
		$convs->[-1][1] .= "\n$message";
	}
	else {
		push @$convs, ['user', $message];
	}

	# TODO: configurable size
	splice @$msgs, 0, -100;
	splice @$convs, 0, -100;
}

sub add_bot_response ($self, $user, $message)
{
	use Data::Dumper; warn Dumper(['add_bot_response', $user, $message]);
	push $self->conversations->{$user}->@*, ['assistant', $message];
}

sub query_ai ($self, $channel, $user, $ret_sub)
{
	use Data::Dumper; warn Dumper(['query_ai', $channel, $user]);
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
			system => $self->system_text($user),
			messages => [
				map {
					+{
						role => $_->[0],
						content => $_->[1],
					}
				} $self->conversations->{$user}->@*
			],
		},
	)->then(sub ($tx) {
		my $res = $tx->result;
		die 'could not connect to claude'
			unless $res->is_success;
		my $reply = $res->json->{content}[0]{text};
		$self->add_bot_response($user, $reply);

		$ret_sub->($reply);
	});

	return;
}

