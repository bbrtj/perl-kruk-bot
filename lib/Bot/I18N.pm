package Bot::I18N;

use v5.40;

use Exporter qw(import);

use Data::Localize;
use Data::Localize::Format::Sprintf;

our @EXPORT = qw(_t);

my $localizer = do {
	my $loc = Data::Localize->new();

	$loc->add_localizer(
		class => 'YAML',
		path => 'i18n/*.yml',
		formatter => Data::Localize::Format::Sprintf->new,
	);

	$loc->auto(0);
	$loc->set_languages($ENV{KRUK_LANG} // 'en');

	$loc;
};

sub _t ($key, @args)
{
	my $localized = $localizer->localize($key, @args);

	if (!defined $localized) {
		Bot::Log->singleton->error("did not find translation for $key");
		die 'missing translation';
	}

	return $localized;
}

