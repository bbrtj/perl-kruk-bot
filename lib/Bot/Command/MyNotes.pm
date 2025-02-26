package Bot::Command::MyNotes;

use v5.40;

use Mooish::Base;

use Bot::I18N;

extends 'Bot::Command';

use constant name => 'mynotes';
use constant syntax => _t 'command.mynotes.help.syntax';
use constant description => _t 'command.mynotes.help.description';

sub run ($self, $ctx, @args)
{
	if (!$args[0]) {
		return $self->bot_instance->notes->dump(
			aspect => $ctx->user,
			ordered => !!1,
			prefix => _t 'command.mynotes.msg.list_prefix'
		) || _t 'command.mynotes.msg.no_notes';
	}
	elsif (@args == 2 && $args[0] eq 'remove' && PositiveOrZeroInt->check($args[1])) {
		my $removed = $self->bot_instance->notes->remove(aspect => $ctx->user, id => $args[1]);

		return $removed
			? _t 'command.mynotes.msg.removed'
			: _t 'command.mynotes.msg.not_removed'
			;
	}

	die $self->bad_arguments;
}

