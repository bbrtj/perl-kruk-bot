package HTML::FormatGist;

use v5.40;
use List::Util qw(any);
use HTML::Tagset;

use parent 'HTML::Formatter';

my @skippable_els = qw(nav header footer);

# needed for HTML::Element to find these in look_down
$HTML::Tagset::isBodyElement{$_} = 1 for @skippable_els;

sub out
{
	my ($self, $text) = @_;

	if (defined $self->{vspace}) {
		undef $self->{vspace};
		$self->collect("\n");
	}

	$self->collect($text);
}

sub pre_out
{
	my ($self, $text) = @_;

	$self->out("```\n$text\n```");
}

sub adjust_lm { }
sub adjust_rm { }

sub format
{
	my ($self, $tree) = @_;

	my $unneeded = sub {
		my $tag = fc $_[0]->tag;
		return any { $tag eq fc $_ } @skippable_els;
	};

	foreach my $element ($tree->look_down($unneeded)) {
		$element->destroy;
	}

	return $self->SUPER::format($tree);
}

