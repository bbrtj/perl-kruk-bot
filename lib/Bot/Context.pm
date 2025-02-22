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

has field 'response' => (
	isa => Str,
	writer => 1,
	predicate => 1,
);

has field 'timestamp' => (
	isa => PositiveInt,
	default => sub { time },
);

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

