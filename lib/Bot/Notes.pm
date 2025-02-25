package Bot::Notes;

use v5.40;

use Mooish::Base;
use Bot::Schema::Note;

sub store ($self, $note, %args)
{
	my $item = Bot::Schema::Note->new(
		context => $args{aspect},
		reason => $args{reason},
		content => $note,
	);

	$item->prepare_and_save;
	return $item->id;
}

sub retrieve ($self, %args)
{
	return Bot::Schema::Note::Manager->get_notes(
		query => [
			context => $args{aspect}
		]
	);
}

sub remove ($self, %args)
{
	return Bot::Schema::Note::Manager->delete_notes(
		where => [
			id => $args{id},
			context => $args{aspect},
		],
	);
}

sub dump ($self, %args)
{
	my $notes = $self->retrieve(%args);
	if (@$notes) {
		my @note_texts;
		if ($args{ordered}) {
			@note_texts = map { $_->id . ": " . $_->content } @$notes;
		}
		else {
			@note_texts = map { $_->content } @$notes;
		}

		return join "\n", grep { defined }
			$args{prefix},
			@note_texts;
	}

	return '';
}

