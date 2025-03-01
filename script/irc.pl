#!/usr/bin/env perl

use v5.40;
use Mojo::File qw(curfile);
use lib curfile->dirname->dirname->child('lib')->to_string;

use Env::Dot;
use Bot;
use Bot::IRC;

my $bot = Bot->new(environment => 'irc');
my $irc = Bot::IRC->new;

$irc->configure(
	sub ($msg) {
		my $ctx = $bot->get_context($msg);

		$bot->add_message($ctx);

		return unless $msg->{for_me};

		$bot->query($ctx);
		$ctx->promise->then(
			sub {
				$irc->speak($ctx);
			}
		);
	}
);

$irc->connect;

$SIG{INT} = sub { Mojo::IOLoop->stop };
Mojo::IOLoop->start;

