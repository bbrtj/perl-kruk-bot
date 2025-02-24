package Bot::Command;

use v5.40;

use Mooish::Base;

has param 'bot_instance' => (
	isa => InstanceOf ['Bot'],
	weak_ref => 1,
);

use constant prefix => '.';
use constant bad_arguments => {hint => 'invalid command arguments'};
use constant bad_alter_arguments => {hint => 'invalid alter command arguments'};
use constant can_alter => !!0;

sub run ($self, $ctx, @args)
{
	...;
}

sub alter ($self, $ctx, @args)
{
	...;
}

sub name ($self)
{
	...;
}

sub syntax ($self)
{
	...;
}

sub get_usage ($self)
{
	$self->prefix . $self->name . '(' . $self->syntax . ')';
}

sub register ($class, $bot, %args)
{
	return ($class->name => $class->new(%args, bot_instance => $bot));
}

