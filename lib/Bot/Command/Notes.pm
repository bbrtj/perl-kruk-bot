package Bot::Command::Notes;

use v5.40;

use Mooish::Base;

extends 'Bot::Command';

use constant name => 'notes';
use constant syntax => '(remove <n>)';

sub runner ($self, $ctx, @args)
{
	if (!$args[0]) {
		return "Here is my diary:\n" . $self->bot_instance->self_notes->dump(ordered => !!1);
	}
	elsif (@args == 2 && $args[0] eq 'remove' && PositiveOrZeroInt->check($args[1])) {
		$self->bot_instance->self_notes->remove(index => $args[1]);
		return 'Diary entry removed.';
	}

	die $self->bad_arguments;
}

