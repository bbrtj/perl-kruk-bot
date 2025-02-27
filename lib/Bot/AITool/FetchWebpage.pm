package Bot::AITool::FetchWebpage;

use v5.40;

use Mooish::Base;
use Mojo::URL;
use HTML::TreeBuilder;
use HTML::FormatText;
use Encode qw(decode);
use List::Util qw(any);

use Bot::I18N;

# needed for HTML::Element to find these in look_down
$HTML::Tagset::isBodyElement{nav} = 1;
$HTML::Tagset::isBodyElement{header} = 1;
$HTML::Tagset::isBodyElement{footer} = 1;

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
	my $url = $input->{url};
	$url = "https://$url" unless $url =~ m{^https?://};

	return $self->ua->get_p($url)->then(
		sub ($tx) {
			my $res = $tx->result;
			$ctx->add_to_response(_t 'tool.fetch_webpage.msg.info', $url, $res->code);
			my $content_type = $res->headers->content_type // '';
			my $body = $res->text;

			if ($content_type =~ /html/i) {
				my $tree = HTML::TreeBuilder->new->parse_content($body);
				my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 80);

				my $unneeded = sub ($el) {
					my $tag = fc $el->tag;
					return any { $tag eq fc $_ } qw(nav header footer);
				};

				foreach my $element ($tree->look_down($unneeded)) {
					$element->destroy;
				}

				$body = $formatter->format($tree);
				# handle html charset?
				#my $charset_el = $tree->look_down(_tag => 'meta', charset => qr/.+/);
				#$charset = $charset_el->attr('charset') if $charset_el;
			}

			$body =~ s{\h+}{ }g;
			$body =~ s{\v\h?\v}{\n}g;

			return $body;
		},
		sub ($err) {
			$ctx->add_to_response(_t 'tool.fetch_webpage.err.failed', $url);
			return "Error fetching webpage: $err";
		}
	);
}

