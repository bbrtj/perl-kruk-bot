#!/usr/bin/env perl

use v5.40;
use lib 'local/lib/perl5';
use lib 'lib';

use Env::Dot;
use Bot;
use Bot::Context;
use Bot::IRC;

my $bot = Bot->new(environment => 'irc');
my $irc = Bot::IRC->new;

$irc->configure(
	sub ($msg) {
		my $ctx = Bot::Context->new($msg);

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

