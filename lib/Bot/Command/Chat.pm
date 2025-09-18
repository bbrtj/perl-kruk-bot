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
	elsif ($self->check_clear($ctx, @args)) {
		$self->clear($ctx);
		return _t 'command.chat.msg.cleared';
	}
	elsif ($self->check_read($ctx, @args)) {
		$self->read($ctx);
		return _t 'command.chat.msg.read';
	}

	die $self->bad_arguments;
}

sub alter ($self, $ctx, @args)
{
	if ($self->check_clear($ctx, @args)) {
		$self->clear($ctx, !!1);
	}
	elsif ($self->check_read($ctx, @args)) {
		$self->read($ctx, !!1);
	}
	else {
		die $self->bad_alter_arguments;
	}

}

sub check_clear ($self, $ctx, @args)
{
	return @args == 1 && $args[0] eq 'clear';
}

sub check_read ($self, $ctx, @args)
{
	return @args == 1 && $args[0] eq 'read' && $ctx->has_channel;
}

sub clear ($self, $ctx, $alter = !!0)
{
	$self->bot_instance->get_conversation($ctx)->clear;
	$ctx->config->set_chat_log('');
}

sub read ($self, $ctx, $alter = !!0)
{
	my $chat_data = "Chat log:\n" . join "\n",
		map { "$_->[0] said: $_->[1]" }
		$self->bot_instance->observed_messages->{$ctx->channel}->@*;

	$ctx->config->set_chat_log($chat_data);
}

