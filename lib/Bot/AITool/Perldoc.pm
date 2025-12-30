package Bot::AITool::Perldoc;

use v5.40;

use Mooish::Base;

use Bot::I18N;
use Storage::Abstract;

use IPC::Open3;
use Symbol 'gensym';

extends 'Bot::AITool';

use constant name => 'perldoc';

sub _build_definition ($self)
{
	return {
		name => $self->name,
		description =>
			q{Get the source of any installed perl module with perldoc. This allows reaching for perl code of modules from outside this project. Use for modules not found in this project.},
		input_schema => {
			type => 'object',
			required => ['module'],
			properties => {
				module => {
					type => 'string',
					description => 'Name of the module',
				},
			},
		},
	};
}

sub runner ($self, $ctx, $input)
{
	$ctx->add_to_response("Getting the source of $input->{module}");

	try {
		my $pid = open3(undef, my $output, my $error = gensym, 'perldoc', '-T', '-m', $input->{module});

		my $contents = do {
			local $/;
			readline $output;
		};
		my $errors = do {
			local $/;
			readline $error;
		};
		waitpid $pid, 0;

		my $status = $? >> 8;
		die "code $status: $errors"
			if $status != 0;

		return $contents;
	}
	catch ($ex) {
		return "Exception occured: $ex";
	}
}

