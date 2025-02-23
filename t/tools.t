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

	is $bot->conversations->{$ctx->user}[-1][0], 'user', 'last entry is user role ok';
	like $bot->conversations->{$ctx->user}[-1][1][0]{content}[0]{text}, qr/about me/i, 'website data looks ok';
	is $ctx->response_extras->[0], 'fetching https://bbrtj.eu', 'user informed ok';
};

done_testing;

