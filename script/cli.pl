#!/usr/bin/env perl

use v5.40;
use Mojo::File qw(curfile);
use lib curfile->dirname->dirname->child('lib')->to_string;

use Env::Dot;
use Bot;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN, ':encoding(UTF-8)';

my $bot = Bot->new(environment => 'cli');
my $user = $bot->owner;

while ('talking with AI') {
	print "> ";
	my $msg = readline STDIN;
	last unless defined $msg;
	chomp $msg;

	my $ctx = $bot->get_context(
		user => $user,
		message => $msg,
	);

	$bot->add_message($ctx);
	$bot->query($ctx);
	$ctx->promise->wait;
	say $ctx->full_response;
}

