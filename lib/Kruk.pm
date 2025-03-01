package Kruk;

use v5.40;

use Mojo::File qw(curfile);

# commonalities for all aspects of Kruk

sub root_dir ($self)
{
	return curfile->dirname->dirname;
}

