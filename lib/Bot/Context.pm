package Bot::Context;

use v5.40;

use Mooish::Base;
use List::Util qw(any);

has param 'channel' => (
	isa => Maybe [SimpleStr],
	default => undef,
);

has param 'user' => (
	isa => SimpleStr,
);

has param 'message' => (
	isa => Str,
);

has field 'response_extras' => (
	isa => ArrayRef,
	default => sub { [] },
);

has field 'response' => (
	isa => Str,
	writer => 1,
	predicate => 1,
);

has field 'timestamp' => (
	isa => PositiveInt,
	default => sub { time },
);

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

