package Bot::AITool::FetchWebpage;

use v5.40;

use Mooish::Base;
use Mojo::IOLoop;
use IPC::Open3;
use Mojo::URL;
use Symbol 'gensym';

extends 'Bot::AITool';

use constant name => 'fetch_webpage';

sub _build_definition ($self)
{
	return {
		name => $self->name,
		description => q{Fetch a webpage from the Internet. Don't fetch a page without asking.},
		input_schema => {
			type => 'object',
			required => ['url'],
			properties => {
				url => {
					type => 'string',
					description => 'An URL of a webpage to fetch. Https will be assumed',
				},
			}
		},
	};
}

sub runner ($self, $ctx, $input)
{
	return Mojo::IOLoop->subprocess->run_p(
		sub {
			my $url = Mojo::URL->new($input->{url});
			$url->scheme('https') if !$url->scheme;

			my $pid = open3(my $stdin, my $stdout, my $stderr = gensym, 'tools/page_reader/script.mjs', "$url");
			waitpid $pid, 0;

			local $/;
			my $status = $? >> 8;

			if ($status != 0) {
				my $err = 'Could not fetch webpage';
				if ($stderr) {
					$err .= ', ' . <$stderr>;
				}

				die $err;
			}
			return <$stdout>;
		}
	);
}

