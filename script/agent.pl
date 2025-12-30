#!/usr/bin/env perl

use v5.40;
use Mojo::File qw(curfile path);
use lib curfile->dirname->dirname->child('lib')->to_string;

use Env::Dot;
use Bot;

use Bot::AITool::AccessFiles;
use Bot::AITool::ListFiles;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN, ':encoding(UTF-8)';

my $directory = shift();
die 'bad directory'
	unless $directory && -d $directory;

my @prompts;
if (-f "$directory/.agent") {
	push @prompts, path("$directory/.agent")->slurp;
}

# unique user name for user notes
my $user = 'agent_user_' . path($directory)->basename;

$ENV{KRUK_PRODUCTION} = true;
$ENV{MOJO_INACTIVITY_TIMEOUT} = 300;
my $bot = Bot->new(
	trusted_users => [$user],
	environment => 'agent',
	extra_prompts => \@prompts,
	max_tokens => 64000,
	conversation_lifetime => 99999,
);

$bot->tools->%* = (
	Bot::AITool::SaveUserNote->register($bot),
	Bot::AITool::Perldoc->register($bot),
	Bot::AITool::AccessFiles->register($bot, directory => $directory),
	Bot::AITool::ListFiles->register($bot, directory => $directory),
	Bot::AITool::MoveFiles->register($bot, directory => $directory),
);

while ('talking with AI') {
	print "> ";
	my $msg = readline STDIN;
	last unless defined $msg;
	chomp $msg;

	my $ctx = $bot->get_context(
		user => $user,
		message => $msg,
	);

	$ctx->set_on_response_extra(
		sub ($text) {
			say $text;
		}
	);

	$bot->add_message($ctx);
	$bot->query($ctx);
	$ctx->promise->wait;
	say $ctx->response;
}

