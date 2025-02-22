package Bot::IRC;

use v5.40;

use Mooish::Base;
use Mojo::IRC;
use List::Util qw(any);
use Encode qw(encode decode);
use Bot::Schema::Snippet;
use Web;

has field 'config' => (
	isa => HashRef,
	default => sub {
		+{
			server => $ENV{KRUK_IRC_SERVER},
			channel => $ENV{KRUK_IRC_CHANNEL},
			nick => $ENV{KRUK_IRC_NICK},
			password => $ENV{KRUK_IRC_PASSWORD},
		};
	},
);

has field 'irc_instance' => (
	isa => InstanceOf ['Mojo::IRC'],
	lazy => sub ($self) {
		Mojo::IRC->new(
			nick => $self->config->{nick},
			user => $self->config->{nick},
			server => $self->config->{server},
			# tls => {},
		);
	},
);

has field 'web_instance' => (
	isa => InstanceOf ['Web'],
	default => sub { Web->new },
);

has field 'snippet_lifetime' => (
	isa => PositiveInt,
	default => sub { $ENV{KRUK_SNIPPET_LIFETIME} * 60 },
);

sub dispatch ($self, $msg)
{
	my ($channel, $line) = $msg->{params}->@*;
	my $is_private = $channel !~ /^\#/;

	my $conf = $self->config;
	return unless ($is_private && $channel eq $conf->{nick})
		|| (!$is_private && any { $_ eq $channel } split /,/, $conf->{channel});

	my ($user) = $msg->{prefix} =~ /^(\w+)/;

	my $for_me = $is_private;
	if ($line =~ /^(\w+):/) {
		$for_me = fc $1 eq fc $conf->{nick};
		$line =~ s/^\Q$conf->{nick}:\E//i
			if $for_me;
	}

	return {
		user => $user,
		channel => $is_private ? undef : $channel,
		message => $line,
		for_me => $for_me,
	};
}

sub save_snippet ($self, $snippet)
{
	(my $type, $snippet) = split /\v/, $snippet, 2;
	$type = undef unless length $type;

	my $item = Bot::Schema::Snippet->new(
		syntax => $type,
		snippet => $snippet,
	);

	$item->prepare_and_save;
	return $self->web_instance->url_for(snippet => {snippet_id => $item->id});
}

sub speak ($self, $ctx)
{
	my $msg = $ctx->response;
	my $user = $ctx->user;

	$msg =~ s{```(.*?)```}{'[ ' . $self->save_snippet($1) . ' ]'}seg;

	my @lines;
	$msg =~ s/\s{2,}|\n/ /g; # reduce to one line
	$msg = trim $msg;
	my $reply_utf8 = encode 'UTF-8', $msg;
	my $max_line_length = 430 - (!$ctx->has_channel ? 1 : length(encode 'UTF-8', ":$user: "));
	while (length $reply_utf8) {
		my $num = $max_line_length - 1;
		$reply_utf8 =~ s/^(.{,$num}\S)(?:\s|\z)//;
		last if ! defined $1; # it's a bug if this ever happens
		push @lines, decode 'UTF-8', trim($1);
	}

	my $irc = $self->irc_instance;
	if ($ctx->has_channel) {
		$irc->write(privmsg => $ctx->channel, ":$user: $_") foreach splice @lines, 0, 5;
		$irc->write(privmsg => $ctx->channel, ":$user: [response was truncated]") if @lines;
	} else {
		$irc->write(privmsg => $user, ":$_") foreach @lines;
	}
}

sub configure ($self, $react_sub)
{
	my $irc = $self->irc_instance;

	$irc->on(irc_mode => sub ($, $msg) {
		foreach my $channel (split /,/, $self->config->{channel}) {
			$irc->write(join => $channel);
			say 'joining channel ' . $channel;
		}
	});

	$irc->on(irc_join => sub ($, $msg) {
		say "joined channel $msg->{params}[0]";
	});

	$irc->on(irc_notice => sub ($, $msg) {
		if ($msg->{params}[1] =~ /\/msg nickserv identify/i) {
			$irc->write(ns => 'identify', $self->config->{password});
		}
	});

	$irc->on(irc_privmsg => sub ($, $msg) {
		my $msg_data = $self->dispatch($msg);
		return if !$msg_data;

		$react_sub->($msg_data);
	});

	$irc->ioloop->recurring(60 => sub {
		my $threshold = time - $self->snippet_lifetime;

		my $expired = Bot::Schema::Snippet::Manager->get_snippets(
			query => [
				created_at => { lt => $threshold },
			],
		);

		foreach my $item (@$expired) {
			$item->delete;
		}
	});
}

sub connect ($self)
{
	$self->irc_instance->connect(sub ($irc, $err) {
		say 'connected';
		warn $err if $err;
	});
}

