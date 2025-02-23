package Bot::AITool::FetchWebpage;

use v5.40;

use Mooish::Base;
use Mojo::URL;
use HTML::TreeBuilder;
use HTML::FormatText;
use Encode qw(decode);
use List::Util qw(any);

# needed for HTML::Element to find these in look_down
$HTML::Tagset::isBodyElement{nav} = 1;
$HTML::Tagset::isBodyElement{header} = 1;
$HTML::Tagset::isBodyElement{footer} = 1;

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
	my $url = $input->{url};
	$url = "https://$url" unless $url =~ /^http/;
	$ctx->add_to_response("fetching $url");

	return $self->bot_instance->ua->get_p($url)->then(
		sub ($tx) {
			my $res = $tx->result;
			my $body = $res->body;
			my ($charset) = $res->headers->content_type =~ /; charset=([^;]+)/;

			if ($res->headers->content_type =~ /html/i) {
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
				$charset ||= $tree->look_down(_tag => 'meta', charset => qr/.+/)->attr('charset');
			}

			$charset ||= 'utf-8';
			$body = decode $charset, $body;
			$body =~ s{\h+}{ }g;
			$body =~ s{\v\h?\v}{\n}g;

			return $body;
		},
		sub ($err) {
			return $err;
		}
	);
}

