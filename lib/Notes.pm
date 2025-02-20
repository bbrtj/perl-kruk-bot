package Notes;

use v5.40;

use Moo;
use Mooish::AttributeBuilder;
use Types::Common -types;

has param 'context' => (
	isa => Str,
);

has field 'storage' => (
	isa => HashRef,
	default => sub { {} },
);

sub store ($self, $note, %args)
{
	push $self->storage->{$args{aspect} // 'none'}->@*, $note;
}

sub retrieve ($self, %args)
{
	return $self->storage->{$args{aspect} // 'none'} // [];
}

sub dump ($self, %args)
{
	my $notes = $self->retrieve(%args);
	if (@$notes) {
		return join "\n", grep { defined }
			$args{prefix},
			@$notes;
	}

	return '';
}

