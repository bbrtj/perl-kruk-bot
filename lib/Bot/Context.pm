package Bot::Context;

use v5.40;

use Mooish::Base;
use Mojo::Promise;
use List::Util qw(any);
use Bot::Conversation::Config;

has param 'channel' => (
	isa => Maybe [SimpleStr],
	default => undef,
);

has param 'user' => (
	isa => SimpleStr,
);

has param 'message' => (
	isa => Str,
	writer => 1,
);

has field 'config' => (
	isa => InstanceOf ['Bot::Conversation::Config'],
	writer => 1,
);

has field 'promise' => (
	isa => InstanceOf ['Mojo::Promise'],
	default => sub { Mojo::Promise->new },
);

has field 'response_extras' => (
	isa => ArrayRef,
	default => sub { [] },
);

has field 'response' => (
	isa => Str,
	writer => -hidden,
	predicate => 1,
);

has field 'timestamp' => (
	isa => PositiveInt,
	default => sub { time },
);

has field 'retries' => (
	isa => PositiveOrZeroInt,
	default => 0,
	writer => -hidden,
);

sub set_response ($self, $text)
{
	$self->_set_response($text);
	$self->promise->resolve;
	return;
}

sub add_to_response ($self, $text)
{
	push $self->response_extras->@*, $text;
}

sub full_response ($self)
{
	my @extras = $self->response_extras->@*;
	@extras = map { "<$_>" } @extras;

	return join ' ', @extras, $self->response;
}

sub has_channel ($self)
{
	return defined $self->channel;
}

sub channel_text ($self)
{
	return $self->channel // '';
}

sub user_of ($self, $users_aref)
{
	my $user = fc $self->user;
	return any { $user eq fc } $users_aref->@*;
}

sub failure ($self, %params)
{
	if (!$params{retry}) {
		$self->set_response("AI fatal failure, did not get a response");
		return;
	}

	$params{max_tries} //= 3;
	my $retries = $self->retries;
	$self->_set_retries(++$retries);
	$self->set_response("AI failure: tried $params{max_tries} times but did not get a response")
		if $retries >= $params{max_tries};
}

