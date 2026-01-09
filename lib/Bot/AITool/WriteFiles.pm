package Bot::AITool::WriteFiles;

use v5.40;

use Mooish::Base;

use Bot::I18N;
use Storage::Abstract;

extends 'Bot::AITool';

use constant name => 'write_files';

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
			q{Write a file on user's machine. Use this output contents to a file. If possible, try replacing with pattern, even if it means calling the tool multiple times},
		input_schema => {
			type => 'object',
			required => ['file_path', 'contents'],
			properties => {
				file_path => {
					type => 'string',
					description => 'Relative path to a file inside this project. Uses unix directory separators',
				},
				contents => {
					type => 'string',
					description =>
						'New contents of a file',
				},
				pattern => {
					type => 'string',
					description =>
						'Old text to replace. If specified, the first occurence of that exact text will be replaced with "contents". If not, the entire file will be replaced. It must occur in file literally, including whitespace',
				},
			},
		},
	};
}

sub runner ($self, $ctx, $input)
{
	my $file = $input->{file_path};
	my $new_content = $input->{contents};
	my $replace = $input->{pattern};

	my $scope = defined $replace ? '(replacing ' . length($replace) . ' bytes)' : '(entire file)';

	$ctx->add_to_response("writing $file $scope");

	try {
		if (defined $replace) {
			my $fh = $self->storage->retrieve($file);
			my $content = join '', readline $fh;

			my $replaced = $content =~ s{\Q$replace\E}{$new_content};
			die 'pattern not found in the file' unless $replaced;

			$new_content = $content;
		}

		$self->storage->store($file, \$new_content);
		return "file has been saved";
	}
	catch ($ex) {
		return "Exception occured: $ex";
	}
}

