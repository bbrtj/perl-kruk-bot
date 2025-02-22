use Test2::V0;
use Bot::IRC;
use Bot::Schema::Snippet;

use v5.40;
use utf8;

my $irc = Bot::IRC->new;
my $long_text = trim(<<~TEXT);
Słońce powoli chyliło się ku zachodowi, rzucając pomarańczowe refleksy na kamienne bruki starego miasteczka. Maria siedziała na drewnianej ławce, mocno zaciskając dłonie na białej torebce. Była zmęczona długą podróżą z oddalonej o setki kilometrów wioski, gdzie spędziła całe swoje dotychczasowe życie. Mijający ludzie rzucali jej przelotne, obojętne spojrzenia. Starcy popijający piwo przed lokalną żabką, młode matki prowadzące swoje pociechy na popołudniowy spacer, dorośli wracający z pracy - wszyscy zdawali się być częścią tego małego, spokojnego świata, podczas gdy ona była tu zupełnie obca. W oddali usłyszała dźwięk kościelnych dzwonów. Ich melodyjny głos rozbrzmiewał między kamienicami, przypominając o upływającym czasie. Kiedyś te dźwięki oznaczały dla niej wakacje, odwiedziny u dalekiej rodziny, beztroskie dzieciństwo. Teraz brzmiały jak wyrok, jak nieubłagalne przypomnienie o zmianach, które nadchodzą. Nagle zerwał się chłodny wiatr, poruszając jej włosami i rozrzucając drobne śmieci po brukowanym chodniku. Maria drgnęła, jakby wyrwana z transu, i powoli podniosła się z ławki. Przed nią rozciągała się nieznana przyszłość - pełna nadziei, ale i nieoczywistych wyborów.
TEXT
my $short_text = 'zażółć gęślą jaźń';

subtest 'should partition long text' => sub {
	my $partitioned = $irc->partition_text($long_text, ':');
	isnt scalar @$partitioned, 1, 'text got partitioned ok';
	is join(' ', @$partitioned), $long_text, 'text ok';
};

subtest 'should partition short text' => sub {
	my $partitioned = $irc->partition_text($short_text, ':');
	is scalar @$partitioned, 1, 'text fits ok';
	is $partitioned->[0], $short_text, 'text ok';
};

subtest 'should save snippet' => sub {
	my $url = $irc->save_snippet($long_text);
	if ($url =~ m{^http://localhost:3000/snippet/(\w+)}) {
		my $item = Bot::Schema::Snippet->new(id => $1);
		ok $item->load(speculative => !!1), 'item exists in the database';
		is $item->snippet, $long_text, 'snippet saved ok';
		is $item->syntax, undef, 'syntax is null ok';
	}
	else {
		fail 'snippet url is not a valid link';
		note $url;
	}
};

subtest 'should store snippet syntax' => sub {
	my $url = $irc->save_snippet("perl\n" . $long_text);
	if ($url =~ m{^http://localhost:3000/snippet/(\w+)}) {
		my $item = Bot::Schema::Snippet->new(id => $1);
		ok $item->load(speculative => !!1), 'item exists in the database';
		is $item->syntax, 'perl', 'syntax is perl ok';
	}
	else {
		fail 'snippet url is not a valid link';
		note $url;
	}
};

done_testing;

