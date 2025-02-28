package Bot::AITool::FetchWebpage;

use v5.40;

use Mooish::Base;
use HTML::TreeBuilder;
use HTML::FormatGist;

use Bot::I18N;

extends 'Bot::AITool';

has field 'ua' => (
	isa => InstanceOf ['Mojo::UserAgent'],
	default => sub {
		Mojo::UserAgent->new(
			connect_timeout => 10,
			max_redirects => 3,
		);
	},
);

has param 'max_length' => (
	isa => PositiveInt,
	default => sub { $ENV{KRUK_MAX_WEBPAGE_LENGTH} // 20000 },
);

use constant name => 'fetch_webpage';

# TODO: allow AI to search for a specific text in the website?
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

sub _validate_content_type ($self, $ct)
{
	die 'no content type' unless defined $ct;

	my $is_text = $ct =~ m{^text/};
	my $is_application = $ct =~ m{^application/};
	my $supported_application = $is_application && $ct =~ m{json|xml};

	die 'unsupported content type' unless $is_text || $supported_application;
	return;    # valid
}

sub _record_page ($self, $ctx, $url, $res)
{
	my $body = $res->text;

	if ($res->headers->content_type =~ /html/i) {
		my $tree = HTML::TreeBuilder->new->parse_content($body);
		my $formatter = HTML::FormatGist->new();

		$body = $formatter->format($tree);
	}

	$body =~ s{\h+}{ }g;
	$body =~ s{^\h$}{ }mg;
	$body =~ s{\v+}{\n}g;

	if (length $body > $self->max_length) {
		my $truncated_prompt =
			'... Web page is too large and was truncated. This page cannot be fetched in full because of its size. Do not retry fetching the page.';
		my $percentage = int($self->max_length * 100 / length $body);

		$body = substr $body, 0, $self->max_length - length($truncated_prompt);
		$body .= $truncated_prompt;
		$ctx->add_to_response(_t 'tool.fetch_webpage.msg.info', $url, "truncated to $percentage%");
	}
	else {
		$ctx->add_to_response(_t 'tool.fetch_webpage.msg.info', $url, $res->code);
	}

	return $body;
}

sub runner ($self, $ctx, $input)
{
	my $url = $input->{url};
	$url = "https://$url" unless $url =~ m{^https?://};

	return $self->ua->get_p($url)
		->then(
			sub ($tx) {
				my $res = $tx->result;
				$self->_validate_content_type($res->headers->content_type);
				return ($ctx, $url, $res);
			}
		)
		->then(
			sub { $self->_record_page(@_) },
			sub ($err) {
				$ctx->add_to_response(_t 'tool.fetch_webpage.err.failed', $url);
				return "Error fetching webpage: $err";
			}
		);
}

