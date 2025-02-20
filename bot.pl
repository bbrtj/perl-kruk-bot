use v5.40;
use lib 'lib';

use Env::Dot;
use Bot;
use IRC;

my $bot = Bot->new;
my $irc = IRC->new;

$irc->configure(sub ($msg) {
	$bot->add_message($msg->{channel}, $msg->{user}, $msg->{message});

	if ($msg->{for_me}) {
		$bot->add_bot_query($msg->{user}, $msg->{message});
		$bot->query_ai($msg->{channel}, $msg->{user}, sub ($response) {
			$irc->speak($msg->{channel}, $msg->{user}, $response);
		});
	}
});

$irc->connect;
Mojo::IOLoop->start;

