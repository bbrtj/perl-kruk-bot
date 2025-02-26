package Data::Localize::Format::Sprintf;

use Moo;

extends 'Data::Localize::Format';

sub format
{
	my ($self, $lang, $value, @args) = @_;

	return sprintf $value, @args;
}

1;

