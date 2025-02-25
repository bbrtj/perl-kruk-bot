# HARNESS-DURATION-MEDIUM
use Test2::V0;
use Bot;
use Bot::Schema::Note;

use v5.40;
use utf8;

my $bot = Bot->new(environment => 'test');

sub build_context ($message)
{
	return $bot->get_context(
		channel => undef,
		user => 'test',
		message => $message,
	);
}

my $usernote = Bot::Schema::Note->new(
	context => 'test',
	content => '--USER--',
	reason => 'ai',
);
$usernote->prepare_and_save;

my $botnote = Bot::Schema::Note->new(
	context => undef,
	content => '--BOT--',
	reason => 'ai',
);
$botnote->prepare_and_save;

subtest 'should fetch diary' => sub {
	my $ctx = build_context('.notes');
	$bot->query($ctx);
	$ctx->promise->finally(
		sub {
			my $content = quotemeta $botnote->content;
			like $ctx->response, qr/$content/, 'bot response ok';
		}
	)->wait;
};

subtest 'should not remove my notes via diary' => sub {
	my $id = $usernote->id;
	my $ctx = build_context(".notes(remove $id)");
	$bot->query($ctx);
	$ctx->promise->finally(
		sub {
			like $ctx->response, qr/not removed/, 'bot response ok';
		}
	)->wait;
};

subtest 'should fetch my notes' => sub {
	my $ctx = build_context('.mynotes');
	$bot->query($ctx);
	$ctx->promise->finally(
		sub {
			my $content = quotemeta $usernote->content;
			like $ctx->response, qr/$content/, 'bot response ok';
		}
	)->wait;
};

subtest 'should not remove diary via my notes' => sub {
	my $id = $botnote->id;
	my $ctx = build_context(".mynotes(remove $id)");
	$bot->query($ctx);
	$ctx->promise->finally(
		sub {
			like $ctx->response, qr/not removed/, 'bot response ok';
		}
	)->wait;
};

subtest 'should remove my notes' => sub {
	my $id = $usernote->id;
	my $ctx = build_context(".mynotes(remove $id)");
	$bot->query($ctx);
	$ctx->promise->finally(
		sub {
			like $ctx->response, qr/(?<!not) removed/, 'bot response ok';
		}
	)->wait;
};

subtest 'should remove diary' => sub {
	my $id = $botnote->id;
	my $ctx = build_context(".notes(remove $id)");
	$bot->query($ctx);
	$ctx->promise->finally(
		sub {
			like $ctx->response, qr/(?<!not) removed/, 'bot response ok';
		}
	)->wait;
};

subtest 'diary should be empty' => sub {
	my $ctx = build_context('.notes');
	$bot->query($ctx);
	$ctx->promise->finally(
		sub {
			my $content = quotemeta $botnote->content;
			unlike $ctx->response, qr/$content/, 'bot response ok';
		}
	)->wait;
};

subtest 'my notes should be empty' => sub {
	my $ctx = build_context('.mynotes');
	$bot->query($ctx);
	$ctx->promise->finally(
		sub {
			my $content = quotemeta $usernote->content;
			unlike $ctx->response, qr/$content/, 'bot response ok';
		}
	)->wait;
};

done_testing;

