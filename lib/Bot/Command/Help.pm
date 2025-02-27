package Bot::Command::Help;

use v5.40;

use Mooish::Base;

use Bot::I18N;

extends 'Bot::Command';

use constant name => 'help';
use constant syntax => _t 'command.help.help.syntax';
use constant description => _t 'command.help.help.description';

sub run ($self, $ctx, @args)
{
	if (@args == 1) {
		my $command_name = $args[0];
		my $command = $self->bot_instance->commands->{$command_name};

		die {hint => _t 'command.help.err.no_command', $command_name} unless $command;
		return _t 'command.help.msg.usage', $command->get_usage, $command->get_full_description;
	}
	elsif (@args == 0) {
		my $commands = join ', ',
			sort map { $_->name }
			values $self->bot_instance->commands->%*;

		return _t 'command.help.msg.info', $self->prefix, $self->alter_prefix, $commands, $self->get_usage;
	}

	die $self->bad_arguments;
}

