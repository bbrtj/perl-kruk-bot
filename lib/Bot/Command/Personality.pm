package Bot::Command::Personality;

use v5.40;

use Mooish::Base;
use List::Util qw(any);

extends 'Bot::Command';

use constant name => 'personality';
use constant syntax => '[<name>]';
use constant description => 'show and modify bot personalities (for you). Alters a message';
use constant can_alter => !!1;

sub run ($self, $ctx, @args)
{
	if (!$args[0]) {
		return
			qq{You are currently talking with "@{[$self->current($ctx)]}" bot. Other possible options are: @{[join ', ', $self->list]}};
	}
	elsif ($self->check_switch(@args)) {
		$self->switch($ctx, $args[0]);
		return 'Personality modified';
	}

	die $self->bad_arguments;
}

sub alter ($self, $ctx, @args)
{
	die $self->bad_alter_arguments unless $self->check_switch(@args);

	$self->switch($ctx, $args[0], !!1);
}

sub list ($self)
{
	return map { /personality\.(\w+)\.ep/; $1 } glob 'prompts/personality.*.ep';
}

sub current ($self, $ctx)
{
	return $self->bot_instance->get_conversation($ctx)->config->personality;
}

sub check_switch ($self, @args)
{
	return @args == 1 && SimpleStr->check($args[0]);
}

sub switch ($self, $ctx, $personality, $alter = !!0)
{
	die {hint => 'no such personality'} unless any { $personality eq $_ } $self->list;

	if ($alter) {
		$ctx->config->set_personality($personality);
	}
	else {
		$self->bot_instance->get_conversation($ctx)->config->set_personality($personality);
	}
}

