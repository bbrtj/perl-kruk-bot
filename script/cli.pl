#!/usr/bin/env perl

use v5.40;
use lib 'local/lib/perl5';
use lib 'lib';

use Env::Dot;
use Bot;
use Mojo::IOLoop;
use Time::HiRes qw(ualarm);
use Bot::Context;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN, ':encoding(UTF-8)';

my $bot = Bot->new;
my $user = $bot->owner;
my $ctx;
my $awaiting_input = !!0;

Mojo::IOLoop->recurring(
	0.1 => sub {
		return if !$ctx || !$ctx->has_response;

		say $ctx->response;
		$ctx = undef;
	}
);

Mojo::IOLoop->recurring(
	0.1 => sub {
		return if $ctx;

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
		}
		catch ($e) {
			return if $e =~ /noinput/;
		}

		alarm 0;
		$awaiting_input = !!0;

		$ctx = Bot::Context->new(
			user => $user,
			message => $msg,
		);

		return if $bot->handle_command($ctx);

		$bot->add_message($ctx);
		$bot->add_bot_query($ctx);
		$bot->query_bot($ctx);
	}
);

$SIG{INT} = sub { Mojo::IOLoop->stop };
Mojo::IOLoop->start;

