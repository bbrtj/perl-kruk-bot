package Bot::AITool::ListFiles;

use v5.40;

use Mooish::Base;

use Bot::I18N;
use Storage::Abstract;

extends 'Bot::AITool';

use constant name => 'list_files';

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
			q{Lists files available in this project},
		input_schema => {
			type => 'object',
			required => ['reason', 'extensions'],
			properties => {
				reason => {
					type => 'string',
					description =>
						'Explain why you are performing this action, so that user will know what you are doing',
					example => 'searching for location of MyModule',
				},
				extensions => {
					type => 'string',
					description => 'comma-separated list of file extensions to include, without dot',
					example => 'pm,t',
				},
			},
		},
	};
}

sub runner ($self, $ctx, $input)
{
	$ctx->add_to_response("searching for $input->{extensions}: $input->{reason}");

	my @files = $self->storage->list->@*;

	# exclude dotfiles
	@files = grep { $_ !~ m{^\.|/\.} } @files;

	# exclude common dirs
	@files = grep { $_ !~ m{^local/|^node_modules/} } @files;

	my @orig_files = @files;
	@files = ();

	# include extensions
	foreach my $ext (split /,/, $input->{extensions}) {
		@files = (@files, grep { $_ =~ m{\.\Q$ext\E$} } @orig_files);
	}

	return join "\n", @files;
}

