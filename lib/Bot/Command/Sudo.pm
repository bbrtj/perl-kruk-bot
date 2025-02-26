package Bot::Command::Sudo;

use v5.40;

use Mooish::Base;

extends 'Bot::Command';

use constant name => 'sudo';
use constant syntax => '';
use constant description => 'access privacy-violating bot functions';
use constant can_run => !!0;
use constant can_alter => !!1;

sub alter ($self, $ctx, @args)
{
	$self->bad_alter_arguments
		unless @args == 0;
	$ctx->config->set_sudo(!!1);
}

