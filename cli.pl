use v5.40;
use lib 'lib';

use Env::Dot;
use Bot;
use Mojo::IOLoop;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN, ':encoding(UTF-8)';

my $bot = Bot->new;
my $channel = 'terminal';
my $user = 'terminal';
my $awaiting_response = !!0;

Mojo::IOLoop->recurring(1 => sub {
	return if $awaiting_response;

	my $msg = readline STDIN;
	chomp $msg;

	$bot->add_message($channel, $user, $msg);
	$bot->add_bot_query($user, $msg);
	$bot->query_ai($channel, $user, sub ($response) {
		say $response;
		$awaiting_response = !!0;
	});

	$awaiting_response = !!1;
});

Mojo::IOLoop->start;

