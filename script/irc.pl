#!/usr/bin/env perl

use v5.40;
use Mojo::File qw(curfile);
use lib curfile->dirname->dirname->child('lib')->to_string;

use Env::Dot;
use Bot;
use Bot::IRC;

my $bot = Bot->new(environment => 'irc');
my $irc = Bot::IRC->new;

$bot->on_new_context(
	sub ($ctx) {
		$ctx->promise->then(
			sub {
				$irc->speak($ctx);
			}
		);
	}
);

$irc->configure(
	sub ($msg) {
		my $ctx = $bot->get_context($msg);

		$bot->add_message($ctx);
		$bot->query($ctx)
			if $msg->{for_me};
	}
);

$irc->connect;

$SIG{INT} = sub { Mojo::IOLoop->stop };
Mojo::IOLoop->start;

