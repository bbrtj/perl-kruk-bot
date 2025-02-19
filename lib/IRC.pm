package IRC;

use v5.40;

use Moo;
use Mooish::AttributeBuilder;
use Types::Standard -types;
use Mojo::IRC;
use Mojo::IOLoop;
use Encode qw(encode decode);

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

has field 'joined' => (
	isa => Bool,
	writer => 1,
	default => !!0,
);

# TODO: not needed?
has field 'identified' => (
	isa => Bool,
	writer => 1,
	default => !!0,
);

sub dispatch ($self, $msg)
{
	my ($channel, $line) = $msg->{params}->@*;
	my $is_private = $channel !~ /^\#/;

	my $conf = $self->config;
	return unless ($is_private && $channel eq $conf->{nick})
		|| (!$is_private && $channel eq $conf->{channel});

	my ($user) = $msg->{prefix} =~ /^(\w+)/;

	my $for_me = !!0;
	if ($line =~ /^(\w+):/) {
		$for_me = fc $1 eq fc $conf->{nick};
	}

	return {
		user => $user,
		channel => $is_private ? undef : $channel,
		message => $line,
		for_me => $for_me,
	};
}

sub speak ($self, $channel, $user, $msg)
{
	my $is_private = !defined $channel;
	$msg =~ s{(```.*?```)}{(UNIMPLEMENTED)}sg;
	#my @snippets;
	#$reply =~ s|(```.*?```)|my $doc_id = random_string(17); push @snippets, [$doc_id, $1]; "[ $base_url/$doc_id ]"|seg;
	#if (@snippets) {
	#	my $redis_db = $redis->db;
	#	my $p = Mojo::Promise->all(
	#		map {
	#			my ($doc_id, $doc) = @$_;
	#			$redis_db->set_p($doc_id, $doc, 'EX', $snippet_duration);
	#		} @snippets,
	#	);
	#	await $p;
	#}

	my @lines;
	$msg =~ s/\s{2,}|\n/ /g; # reduce to one line
	$msg = trim $msg;
	my $reply_utf8 = encode 'UTF-8', $msg;
	my $max_line_length = 430 - ($is_private ? 1 : length(encode 'UTF-8', ":$user: "));
	while (length $reply_utf8) {
		my $num = $max_line_length - 1;
		$reply_utf8 =~ s/^(.{,$num}\S)(?:\s|\z)//;
		last if ! defined $1; # it's a bug if this ever happens
		push @lines, decode 'UTF-8', trim($1);
	}

	my $irc = $self->irc_instance;
	if ($is_private) {
		$irc->write(privmsg => $user, ":$_") foreach @lines;
	} else {
		$irc->write(privmsg => $channel, ":$user: $_") foreach splice @lines, 0, 5;
		$irc->write(privmsg => $channel, ":$user: [response was truncated]") if @lines;
	}
}

sub configure ($self, $react_sub)
{
	my $irc = $self->irc_instance;

	$irc->on(irc_mode => sub ($, $msg) {
		if (!$self->joined) {
			$irc->write(join => $self->config->{channel});
			say 'joining channel ' . $self->config->{channel};
		}
	});

	$irc->on(irc_join => sub ($, $msg) {
		if ($msg->{params}[0] eq $self->config->{channel}) {
			$self->set_joined(!!1);
			say 'joined channel';
		}
	});

	$irc->on(irc_notice => sub ($, $msg) {
		if ($msg->{params}[1] =~ /\/msg nickserv identify/i && !$self->identified) {
			$irc->write(ns => 'identify', $self->config->{password});
		}
	});

	$irc->on(irc_privmsg => sub ($, $msg) {
		my $msg_data = $self->dispatch($msg);
		return if !$msg_data;

		$react_sub->($msg_data);
	});
}

sub connect ($self)
{
	$self->irc_instance->connect(sub ($irc, $err) {
		say 'connected';
		warn $err if $err;
	});
}

