package Bot::I18N;

use v5.40;

use Bot::I18N::Core;
use Exporter qw(import);

our @EXPORT = qw(_t);

my $localizer = Bot::I18N::Core->get_handle($ENV{KRUK_LANG} // 'en')
	or die 'could not get localization handle';

sub _t ($key, @args)
{
	my $localized = $localizer->maketext($key, @args);

	if (!defined $localized) {
		Bot::Log->singleton->error("did not find translation for $key");
		die 'missing translation';
	}

	return $localized;
}

