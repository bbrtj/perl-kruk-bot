package Bot::Schema::Note;

use v5.40;

use parent 'Bot::Schema';

__PACKAGE__->meta->setup
	(
		table => 'notes',
		columns => [
			qw(
				id context content reason created_at
			)
		],
		pk_columns => 'id',
	);

__PACKAGE__->meta->make_manager_class('notes');

sub prepare_and_save ($self)
{
	$self->created_at(time)
		unless $self->created_at;

	return $self->save;
}

