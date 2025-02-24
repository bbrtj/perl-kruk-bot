# HARNESS-DURATION-MEDIUM
use Test2::V0;
use Bot;
use Bot::Context;

use v5.40;
use utf8;

my $bot = Bot->new(environment => 'test');

sub build_context ($message)
{
	return Bot::Context->new(
		channel => undef,
		user => 'test',
		message => $message,
	);
}

subtest 'should fetch a webpage' => sub {
	my $ctx = build_context('go to bbrtj.eu');
	my $p = $bot->use_tool(
		$ctx, {
			name => 'fetch_webpage',
			input => {
				url => 'bbrtj.eu',
			}
		}
	);

	$p->wait if $p;

	my $conv = $bot->get_conversation($ctx);
	my $last_message = $conv->messages->[-1];
	is $last_message->[0], 'user', 'last entry is user role ok';
	like $last_message->[1][0]{content}[0]{text}, qr/about me/i, 'website data looks ok';
	is $ctx->response_extras->[0], 'fetching https://bbrtj.eu - 200', 'user informed ok';
};

subtest 'should handle a 404 webpage' => sub {
	my $ctx = build_context('go to bbrtj.eu/test404');
	my $p = $bot->use_tool(
		$ctx, {
			name => 'fetch_webpage',
			input => {
				url => 'bbrtj.eu/test404',
			}
		}
	);

	$p->wait if $p;

	my $conv = $bot->get_conversation($ctx);
	my $last_message = $conv->messages->[-1];
	is $last_message->[0], 'user', 'last entry is user role ok';
	like $last_message->[1][0]{content}[0]{text}, qr/not found/i, 'website data looks ok';
	is $ctx->response_extras->[0], 'fetching https://bbrtj.eu/test404 - 404', 'user informed ok';
};

subtest 'should handle a webpage with unicode' => sub {
	my $ctx = build_context('go to gov.pl');
	my $p = $bot->use_tool(
		$ctx, {
			name => 'fetch_webpage',
			input => {
				url => 'gov.pl',
			}
		}
	);

	$p->wait if $p;

	my $conv = $bot->get_conversation($ctx);
	my $last_message = $conv->messages->[-1];
	is $last_message->[0], 'user', 'last entry is user role ok';
	like $last_message->[1][0]{content}[0]{text}, qr/[śćąę]/i, 'website data looks ok';
	is $ctx->response_extras->[0], 'fetching https://gov.pl - 200', 'user informed ok';
};

subtest 'should handle a non-existing webpage' => sub {
	my $ctx = build_context('go to notapage.pl');
	my $p = $bot->use_tool(
		$ctx, {
			name => 'fetch_webpage',
			input => {
				url => 'notapage.pl',
			}
		}
	);

	$p->wait if $p;

	my $conv = $bot->get_conversation($ctx);
	my $last_message = $conv->messages->[-1];
	is $last_message->[0], 'user', 'last entry is user role ok';
	like $last_message->[1][0]{content}[0]{text}, qr/error fetching webpage/i, 'website data looks ok';
	is $ctx->response_extras->[0], 'fetching https://notapage.pl - failed', 'user informed ok';
};

done_testing;

