package Bot::Schema::Snippet;

use v5.40;

use Data::ULID qw(ulid);

use parent 'Bot::Schema';

__PACKAGE__->meta->setup
	(
		table => 'snippets',
		columns => [
			qw(
				id syntax snippet created_at
			)
		],
		pk_columns => 'id',
	);

__PACKAGE__->meta->make_manager_class('snippets');

sub prepare_and_save ($self)
{
	$self->id(ulid)
		unless $self->id;
	$self->created_at(time)
		unless $self->created_at;

	return $self->save;
}

