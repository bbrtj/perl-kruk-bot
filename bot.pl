use v5.40;
use lib 'lib';

use Env::Dot;
use Bot;
use Bot::Context;
use IRC;
use Data::Dumper;

my $bot = Bot->new;
my $irc = IRC->new;
my @ctxs;

$irc->configure(sub ($msg) {
	my $ctx = Bot::Context->new($msg);
	push @ctxs, $ctx;

	my sub respond ($response) {
		$ctx->set_response($response);
	}

	return if $bot->handle_command($ctx);

	$bot->add_message($ctx);

	if ($msg->{for_me}) {
		$bot->add_bot_query($ctx);
		$bot->query_bot($ctx);
	}
});

Mojo::IOLoop->recurring(0.1 => sub {
	my @new_ctxs;
	my $now = time;

	foreach my $ctx (@ctxs) {
		if ($ctx->has_response) {
			$irc->speak($ctx);
		}
		elsif ($now - $ctx->timestamp > 15) {
			say "response timed out: " . Dumper($ctx);
		}
		else {
			push @new_ctxs, $ctx;
		}
	}

	@ctxs = @new_ctxs;
});

$irc->connect;

$SIG{INT} = sub { Mojo::IOLoop->stop };
Mojo::IOLoop->start;

