package Bot::Notes;

use v5.40;

use Moo;
use Mooish::AttributeBuilder;
use Types::Common -types;
use Tie::Storable;

has param 'context' => (
	isa => Str,
);

has field 'storage' => (
	isa => HashRef,
	default => sub { {} },
);

sub _get_filename ($self)
{
	return sprintf 'notes.%s.storage', $self->context;
}

sub BUILD ($self, @)
{
	tie $self->storage->%*, 'Tie::Storable', $self->_get_filename
		or die 'could not tie storage';
}

sub store ($self, $note, %args)
{
	push $self->storage->{$args{aspect} // 'none'}->@*, $note;
}

sub retrieve ($self, %args)
{
	return $self->storage->{$args{aspect} // 'none'} // [];
}

sub remove ($self, %args)
{
	splice $self->storage->{$args{aspect} // 'none'}->@*, $args{index} // 0, 1;
	return;
}

sub dump ($self, %args)
{
	my $notes = $self->retrieve(%args);
	if (@$notes) {
		my @note_texts = @$notes;
		if ($args{ordered}) {
			my $index = 0;
			@note_texts = map { ($index++) . ": $_" } @note_texts;
		}

		return join "\n", grep { defined }
			$args{prefix},
			@note_texts;
	}

	return '';
}

