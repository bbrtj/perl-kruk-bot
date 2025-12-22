package Bot::AITool::AccessFiles;

use v5.40;

use Mooish::Base;

use Bot::I18N;
use Storage::Abstract;

extends 'Bot::AITool';

use constant name => 'access_files';

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
			q{Read or write a file on user's machine. Use this to understand the environment better, or to output contents to a file},
		input_schema => {
			type => 'object',
			required => ['reason', 'file_path'],
			properties => {
				reason => {
					type => 'string',
					description =>
						'Explain why you are performing this action, so that user will know what you are doing',
				},
				file_path => {
					type => 'string',
					description => 'Relative path to a file inside this project. Uses unix directory separators',
				},
				contents => {
					type => 'string',
					description =>
						'New contents of a file. If specified, file will be overwritten. If this key is not included, file will be read instead.',
				},
			},
		},
	};
}

sub runner ($self, $ctx, $input)
{
	$ctx->add_to_response($input->{reason});

	my $file = $input->{file_path};
	my $new_content = $input->{contents};

	try {
		if (defined $new_content) {
			$self->storage->store($file, \$new_content);
			return "file $file has been saved";
		}
		else {
			my $fh = $self->storage->retrieve($file);
			return join '', readline $fh;
		}
	}
	catch ($ex) {
		return "Exception occured: $ex";
	}
}

