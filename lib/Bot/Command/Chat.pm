package Bot::Command::Chat;

use v5.40;

use Mooish::Base;
use List::Util qw(any);

extends 'Bot::Command';

use constant name => 'chat';
use constant syntax => '[clear]';
use constant description => 'show or modify details about your chat';
use constant can_alter => !!1;

sub run ($self, $ctx, @args)
{
	if (!$args[0]) {
		my $conv = $self->bot_instance->get_conversation($ctx);
		return
			qq{Your current conversation has started @{[$conv->first_message_at->cdate]}}
			. qq{ and has @{[scalar $conv->messages->@*]} messages in it. };
	}
	elsif ($self->check_clear(@args)) {
		$self->clear($ctx);
		return 'Chat cleared';
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

