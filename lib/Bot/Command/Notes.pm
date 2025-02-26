package Bot::Command::Notes;

use v5.40;

use Mooish::Base;

use Bot::I18N;

extends 'Bot::Command';

use constant name => 'notes';
use constant syntax => _t 'command.notes.help.syntax';
use constant description => _t 'command.notes.help.description';

sub run ($self, $ctx, @args)
{
	if (!$args[0]) {
		return $self->bot_instance->notes->dump(
			ordered => !!1,
			prefix => _t 'command.notes.msg.list_prefix'
		) || _t 'command.notes.msg.no_notes';
	}
	elsif (@args == 2 && $args[0] eq 'remove' && PositiveOrZeroInt->check($args[1])) {
		my $removed = $self->bot_instance->notes->remove(id => $args[1]);

		return $removed
			? _t 'command.notes.msg.removed'
			: _t 'command.notes.msg.not_removed'
			;
	}

	die $self->bad_arguments;
}

