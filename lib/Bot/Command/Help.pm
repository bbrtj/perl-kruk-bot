package Bot::Command::Help;

use v5.40;

use Mooish::Base;

extends 'Bot::Command';

use constant name => 'help';
use constant syntax => '[<command>]';
use constant description => 'get help about commands';

sub run ($self, $ctx, @args)
{
	if (@args == 1) {
		my $command_name = $args[0];
		my $command = $self->bot_instance->commands->{$command_name};
		return "No such command: $command_name" unless $command;

		my $usage = $command->get_usage;
		my $descr = $command->get_full_description;
		return "Command usage: $usage, $descr";
	}
	elsif (@args == 0) {
		my $commands = join ', ',
			sort map { $_->name }
			values $self->bot_instance->commands->%*;

		my $prefix = $self->prefix;
		my $alter_prefix = $self->alter_prefix;
		my $usage = $self->get_usage;

		return
			qq{Commands are prefixed by "$prefix". Some commands may alter a message when prefixed with "$alter_prefix". Available commands are: $commands. Type $prefix$usage with command name for more info};
	}

	die $self->bad_arguments;
}

