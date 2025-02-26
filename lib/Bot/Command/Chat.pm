package Bot::Command::Chat;

use v5.40;

use Mooish::Base;

use Bot::I18N;

extends 'Bot::Command';

use constant name => 'chat';
use constant syntax => _t 'command.chat.help.syntax';
use constant description => _t 'command.chat.help.description';
use constant can_alter => !!1;

sub run ($self, $ctx, @args)
{
	if (!$args[0]) {
		my $conv = $self->bot_instance->get_conversation($ctx);
		return _t 'command.chat.msg.info', $conv->first_message_at->cdate, scalar $conv->messages->@*;
	}
	elsif ($self->check_clear(@args)) {
		$self->clear($ctx);
		return _t 'command.chat.msg.cleared';
	}

	die $self->bad_arguments;
}

sub alter ($self, $ctx, @args)
{
	die $self->bad_alter_arguments unless $self->check_clear(@args);

	$self->clear($ctx, !!1);
}

sub check_clear ($self, @args)
{
	return @args == 1 && $args[0] eq 'clear';
}

sub clear ($self, $ctx, $alter = !!0)
{
	$self->bot_instance->get_conversation($ctx)->clear;
}

