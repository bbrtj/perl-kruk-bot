# HARNESS-DURATION-MEDIUM
use Test2::V0;
use Bot;

use v5.40;
use utf8;

use Bot::AITool::Perldoc;

my $bot = Bot->new(environment => 'test');

$bot->tools->%* = (
	$bot->tools->%*,
	Bot::AITool::Perldoc->register($bot),
	Bot::AITool::ListFiles->register($bot, directory => '.'),
);

sub build_context ($message)
{
	return $bot->get_context(
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
	like $last_message->[1][0]{content}[0]{text}, qr/error fetching webpage/i, 'error looks ok';
	is $ctx->response_extras->[0], 'fetching https://notapage.pl - failed', 'user informed ok';
};

subtest 'should reject unsupported content type' => sub {
	my $ctx = build_context('go to https://cdn.perl.org/perlweb/images/icons/header_camel.png');
	my $p = $bot->use_tool(
		$ctx, {
			name => 'fetch_webpage',
			input => {
				url => 'https://cdn.perl.org/perlweb/images/icons/header_camel.png',
			}
		}
	);

	$p->wait if $p;

	my $conv = $bot->get_conversation($ctx);
	my $last_message = $conv->messages->[-1];
	is $last_message->[0], 'user', 'last entry is user role ok';
	like $last_message->[1][0]{content}[0]{text}, qr/unsupported/i, 'unsupported file ok';
	is $ctx->response_extras->[0], 'fetching https://cdn.perl.org/perlweb/images/icons/header_camel.png - failed',
		'user informed ok';
};

subtest 'should truncate a very long page' => sub {
	my $ctx = build_context('go to https://perldoc.perl.org/Locale::Maketext');
	my $p = $bot->use_tool(
		$ctx, {
			name => 'fetch_webpage',
			input => {
				url => 'https://perldoc.perl.org/Locale::Maketext',
			}
		}
	);

	$p->wait if $p;

	my $conv = $bot->get_conversation($ctx);
	my $last_message = $conv->messages->[-1];
	is $last_message->[0], 'user', 'last entry is user role ok';
	is length $last_message->[1][0]{content}[0]{text}, 20000, 'website data length ok';
	like $last_message->[1][0]{content}[0]{text}, qr/do not retry fetching the page./i, 'website data truncated ok';
	like $ctx->response_extras->[0], qr/truncated to \d+%/, 'user informed ok';
};

subtest 'should get a perldoc' => sub {
	my $ctx = build_context('read UNIVERSAL perldoc');
	my $p = $bot->use_tool(
		$ctx, {
			name => 'perldoc',
			input => {
				module => 'UNIVERSAL',
			}
		}
	);

	$p->wait if $p;

	my $conv = $bot->get_conversation($ctx);
	my $last_message = $conv->messages->[-1];
	is $last_message->[0], 'user', 'last entry is user role ok';
	like $last_message->[1][0]{content}[0]{text}, qr/=head1 SYNOPSIS/, 'module content ok';
};

subtest 'should list files' => sub {
	my $ctx = build_context('list files in this project');
	my $p = $bot->use_tool(
		$ctx, {
			name => 'list_files',
			input => {
				reason => 'testing',
				extensions => 't,pm',
			}
		}
	);

	$p->wait if $p;

	my $conv = $bot->get_conversation($ctx);
	my $last_message = $conv->messages->[-1];
	is $last_message->[0], 'user', 'last entry is user role ok';
	like $last_message->[1][0]{content}[0]{text}, qr{t/tools.t}, 'module content ok (tools.t)';
	like $last_message->[1][0]{content}[0]{text}, qr{lib/Bot.pm}, 'module content ok (Bot.pm)';
};

done_testing;

