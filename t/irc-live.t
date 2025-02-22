use Test2::V0;
use IPC::Open3;

use v5.40;
use utf8;

use Mojo::IRC;
use Env::Dot;
use Data::ULID qw(ulid);

$ENV{KRUK_IRC_CHANNEL} = '##bot-autotest';

skip_all 'this test needs LIVE_TEST env var'
	unless $ENV{LIVE_TEST};

my $bot_name = $ENV{KRUK_IRC_NICK};
my $my_name = 'kruktest_' . substr ulid, 6, 6;
my $bot_channel = $ENV{KRUK_IRC_CHANNEL};
my @tests = (
	{
		to => $bot_channel,
		message => "$bot_name: .mynotes",
		validation => sub ($msg) {
			return ($msg =~ /notes about you/i) && ($msg !~ /pancake/i);
		},
	},
	{
		to => $bot_channel,
		message => "secret password is: ABRACADABRA",
	},
	{
		to => $bot_channel,
		message =>
			"$bot_name: sudo read chat and analyze it. Based on its contents, tell me what the secret password is. Only include the password in the reply, nothing else",
		validation => sub ($msg) {
			return scalar $msg =~ /ABRACADABRA/;
		},
	},
	{
		to => $bot_channel,
		message => qq{$bot_name: please note that I like pancakes. If you succeed, answer just "done"},
		validation => sub ($msg) {
			return scalar $msg =~ /done/i;
		},
	},
	{
		to => $bot_channel,
		message => "$bot_name: .mynotes",
		validation => sub ($msg) {
			return ($msg =~ /like/i) && ($msg =~ /pancake/i);
		},
	},
	{
		to => $bot_name,
		message => ".mynotes",
		validation => sub ($msg) {
			return ($msg =~ /like/i) && ($msg =~ /pancake/i);
		},
	},
);

my $pid = open3(my $stdin, my $stdout, my $stderr, 'script/irc.pl');
die "couldn't start script/irc.pl" unless $pid;
sleep 2;

my $irc = Mojo::IRC->new(
	nick => $my_name,
	user => $my_name,
	server => $ENV{KRUK_IRC_SERVER},
);

sub next_test
{
	my $test = $tests[0];
	if (!$test) {
		$irc->ioloop->stop;
		return;
	}

	return if $test->{sent}++;
	$irc->write(privmsg => $test->{to}, ':' . $test->{message});
	if ($test->{validation}) {
		alarm 10;
	}
	else {
		shift @tests;
		next_test();
	}
}

sub validate_test ($prefix, $channel, $msg)
{
	my ($user) = $prefix =~ /^(\w+)/;
	note $msg;

	return !!0 if $channel ne $tests[0]{to} && $channel ne $my_name;
	return !!0 if $user ne $bot_name;
	return !!0 unless $channel eq $my_name || $msg =~ /^\Q$my_name\E:/;

	alarm 0;
	my $test = shift @tests;
	if (!$test) {
		fail 'too many messages';
		$irc->ioloop->stop;
		return !!0;
	}

	ok $test->{validation}->($msg), qq{message "$test->{message}" ok};
	return !!1;
}

$irc->on(
	irc_mode => sub ($, $msg) {
		$irc->write(join => $bot_channel);
	}
);

$irc->on(
	irc_join => sub ($, $msg) {
		if ($msg->{params}[0] eq $bot_channel) {
			next_test;
		}
	}
);

$irc->on(
	irc_privmsg => sub ($, $msg) {
		if (validate_test($msg->{prefix}, $msg->{params}->@*)) {
			next_test;
		}
	}
);

$irc->connect(sub { });

$SIG{ALRM} = sub { $irc->ioloop->stop };
$irc->ioloop->start;

kill 'INT', $pid;
waitpid $pid, 0;
is scalar @tests, 0, 'all tests ok';
done_testing;

