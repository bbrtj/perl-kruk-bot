package Bot::I18N::Core;

use v5.40;

use parent 'Locale::Maketext';
use YAML::PP qw(LoadFile);
use Kruk;

foreach my $file (glob Kruk->root_dir->child('i18n/*.yml')) {
	my ($lang) = $file =~ m{/(\w+)\.yml};
	my @lexicon = LoadFile($file);

	my $self = __PACKAGE__;
	my $lexicon_pkg = sprintf '%s::%s', $self, $lang;
	eval "package $lexicon_pkg; use parent -norequire, '$self'; our %Lexicon; 1;"
		or die "error registering lexicon $lexicon_pkg: $@";

	{
		no strict 'refs';
		%{"${lexicon_pkg}::Lexicon"} = map {
			$_->{id}, $_->{str}
		} @lexicon;
	}
}

sub prepend_if_exists ($self, $param, $with)
{
	return '' unless ($param // '') ne '';
	return "$with$param";
}

