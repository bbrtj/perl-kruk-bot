use v5.40;
use lib 'lib';

use Env::Dot;
use Bot;
use Mojo::IOLoop;
use Time::HiRes qw(ualarm);

binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN, ':encoding(UTF-8)';

my $bot = Bot->new;
my $channel = 'terminal';
my $user = 'terminal';
my $awaiting_response = !!0;
my $awaiting_input = !!0;

Mojo::IOLoop->recurring(0 => sub {
	return if $awaiting_response;

	if (!$awaiting_input) {
		print "> ";
		$awaiting_input = !!1;
	}

	my $msg;
	try {
		local $SIG{ALRM} = sub { die 'noinput' };
		ualarm 100000;
		$msg = readline STDIN;
		chomp $msg;
	} catch ($e) {
		return if $e =~ /noinput/;
	}

	alarm 0;
	$awaiting_input = !!0;

	my sub respond ($response) {
		say $response;
		$awaiting_response = !!0;
	}

	return if $bot->handle_command($channel, $user, $msg, \&respond);

	$bot->add_message($channel, $user, $msg);
	$bot->add_bot_query($user, $msg);
	$bot->query_bot($channel, $user, \&respond);

	$awaiting_response = !!1;
});

$SIG{INT} = sub { Mojo::IOLoop->stop };
Mojo::IOLoop->start;

