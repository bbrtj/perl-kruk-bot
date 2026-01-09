package Bot::AITool::ReadFiles;

use v5.40;

use Mooish::Base;

use Bot::I18N;
use Storage::Abstract;

extends 'Bot::AITool';

use constant name => 'read_files';

has option 'directory' => (
	isa => Str,
);

has param 'storage' => (
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
			q{Read a file on user's machine. Use this to understand the project better},
		input_schema => {
			type => 'object',
			required => ['file_path'],
			properties => {
				file_path => {
					type => 'string',
					description => 'Relative path to a file inside this project. Uses unix directory separators',
				},
			},
		},
	};
}

sub runner ($self, $ctx, $input)
{
	my $file = $input->{file_path};
	$ctx->add_to_response("reading $file");

	try {
		my $fh = $self->storage->retrieve($file);
		return join '', readline $fh;
	}
	catch ($ex) {
		return "Exception occured: $ex";
	}
}

