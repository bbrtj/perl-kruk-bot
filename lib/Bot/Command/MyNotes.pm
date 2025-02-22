package Bot::Command::MyNotes;

use v5.40;

use Mooish::Base;

extends 'Bot::Command';

use constant name => 'mynotes';
use constant syntax => '(remove <n>)';

sub runner ($self, $ctx, @args)
{
	if (!$args[0]) {
		return $self->bot_instance->notes->dump(
			aspect => $ctx->user,
			ordered => !!1,
			prefix => "Here are my notes about you:\n"
		) || 'I have no notes about you';
	}
	elsif (@args == 2 && $args[0] eq 'remove' && PositiveOrZeroInt->check($args[1])) {
		$self->bot_instance->notes->remove(aspect => $ctx->user, id => $args[1]);
		return 'Note about you removed.';
	}

	die $self->bad_arguments;
}

