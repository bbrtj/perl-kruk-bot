package Bot::Conversation::Config;

use v5.40;

use Mooish::Base;

# all configuration should have defaults

has param 'sudo' => (
	isa => Bool,
	default => !!0,
	writer => 1,
);

has param 'personality' => (
	isa => SimpleStr,
	default => 'default',
	writer => 1,
);

# must be even, so that conversation turns will be perserved
has param 'history_size' => (
	isa => PositiveInt,
	default => 50,
	writer => 1,
);

sub clone ($self)
{
	return $self->new(%{$self});
}

