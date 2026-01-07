package Bot::Schema::Log;

use v5.40;

use parent 'Bot::Schema';

__PACKAGE__->meta->setup
	(
		table => 'logs',
		columns => [
			qw(
				id channel username message created_at
			)
		],
		pk_columns => 'id',
	);

__PACKAGE__->meta->make_manager_class('logs');

sub prepare_and_save ($self)
{
	$self->created_at(time)
		unless $self->created_at;

	return $self->save;
}

