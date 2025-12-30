package Bot::AITool::MoveFiles;

use v5.40;

use Mooish::Base;

use Bot::I18N;
use Storage::Abstract;

extends 'Bot::AITool';

use constant name => 'move_files';

has param 'directory' => (
	isa => Str,
);

has field 'storage' => (
	isa => InstanceOf ['Storage::Abstract'],
	default => sub ($self) {
		Storage::Abstract->new(
			driver => 'directory',
			directory => $self->directory,
		);
	},
);

sub _build_definition ($self)
{
	return {
		name => $self->name,
		description =>
			q{Rename files by moving them from one location to another},
		input_schema => {
			type => 'object',
			required => ['old_name', 'new_name'],
			properties => {
				old_name => {
					type => 'string',
					description => 'Name of the existing file',
				},
				new_name => {
					type => 'string',
					description => 'New name of the file',
				},
			},
		},
	};
}

sub runner ($self, $ctx, $input)
{
	$ctx->add_to_response("moving $input->{old_name} to $input->{new_name}");

	try {
		my $fh = $self->storage->retrieve($input->{old_name});
		$self->storage->store($input->{new_name}, $fh);
		close $fh;

		$self->storage->dispose($input->{old_name});
	}
	catch ($ex) {
		return "Exception occured: $ex";
	}

	return 'done';
}

