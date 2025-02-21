package Bot::Command::MyNotes;

use v5.40;

use Mooish::Base;

extends 'Bot::Command';

use constant name => 'mynotes';
use constant syntax => '(remove <n>)';

sub runner ($self, $ctx, @args)
{
	if (!$args[0]) {
		return "Here are my notes about you:\n" . $self->bot_instance->user_notes->dump(aspect => $ctx->user, ordered => !!1);
	}
	elsif (@args == 2 && $args[0] eq 'remove' && PositiveOrZeroInt->check($args[1])) {
		$self->user_notes->remove(aspect => $ctx->user, index => $args[1]);
		return 'Note about you removed.';
	}

	die $self->bad_arguments;
}

