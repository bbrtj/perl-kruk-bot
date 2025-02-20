use v5.40;
use lib 'lib';

use Env::Dot;
use Bot;
use IRC;

my $bot = Bot->new;
my $irc = IRC->new;

$irc->configure(sub ($msg) {
	my sub respond ($response) {
		$irc->speak($msg->{channel}, $msg->{user}, $response);
	}

	return if $bot->handle_command($msg->{channel}, $msg->{user}, $msg->{message}, \&respond);

	$bot->add_message($msg->{channel}, $msg->{user}, $msg->{message});

	if ($msg->{for_me}) {
		$bot->add_bot_query($msg->{user}, $msg->{message});
		$bot->query_bot($msg->{channel}, $msg->{user}, \&respond);
	}
});

$irc->connect;

$SIG{INT} = sub { Mojo::IOLoop->stop };
Mojo::IOLoop->start;

