package Bot::Command::Timer;

use v5.40;

use Mooish::Base;
use Mojo::IOLoop;

use Bot::I18N;

extends 'Bot::Command';

use constant name => 'timer';
use constant syntax => _t 'command.timer.help.syntax';
use constant description => _t 'command.timer.help.description';

use constant MAX_TIMER => 60 * 60 * 1;

sub run ($self, $ctx, @args)
{
	die {hint => _t 'command.timer.err.not_possible'}
		unless defined $self->bot_instance->context_sub;

	die $self->bad_arguments
		unless @args > 1 && PositiveInt->check($args[0]);

	my $time = shift @args;
	die {hint => _t 'command.timer.err.too_long', MAX_TIMER}
		if $time > MAX_TIMER;

	my $message = join ' ', @args;
	my $ctx_cpy = $self->bot_instance->get_context(
		channel => $ctx->channel,
		user => $ctx->user,
		message => '(user-requested timer)',
	);

	Mojo::IOLoop->timer($time => sub { $ctx_cpy->set_response($message) });

	return _t 'command.timer.msg.registered';
}

