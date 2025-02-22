package Bot::Command;

use v5.40;

use Mooish::Base;

has param 'bot_instance' => (
	isa => InstanceOf ['Bot'],
	weak_ref => 1,
);

use constant prefix => '.';
use constant bad_arguments => 'invalid command arguments';

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
	return join ' ', grep { defined && length }
		$self->prefix . $self->name, $self->syntax;
}

sub register ($class, $bot, %args)
{
	return ($class->name => $class->new(%args, bot_instance => $bot));
}

