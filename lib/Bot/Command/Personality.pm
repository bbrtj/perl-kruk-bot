package Bot::Command::Personality;

use v5.40;

use Mooish::Base;
use List::Util qw(any);

use Bot::I18N;

extends 'Bot::Command';

use constant name => 'personality';
use constant syntax => _t 'command.personality.help.syntax';
use constant description => _t 'command.personality.help.description';
use constant can_alter => !!1;

sub run ($self, $ctx, @args)
{
	if (!$args[0]) {
		return _t 'command.personality.msg.info', $self->current($ctx), join ', ', $self->list;
	}
	elsif ($self->check_switch(@args)) {
		$self->switch($ctx, $args[0]);
		return _t 'command.personality.msg.modified';
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
	return $ctx->config->personality;
}

sub check_switch ($self, @args)
{
	return @args == 1 && SimpleStr->check($args[0]);
}

sub switch ($self, $ctx, $personality, $alter = !!0)
{
	die {hint => _t 'command.personality.err.invalid'} unless any { $personality eq $_ } $self->list;

	$ctx->config->set_personality($personality);
	if (!$alter) {
		$self->bot_instance->get_conversation($ctx)->config->set_personality($personality);
	}
}

