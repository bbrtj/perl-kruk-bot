package IRC;

use v5.40;

use Moo;
use Mooish::AttributeBuilder;
use Types::Common -types;
use Mojo::IRC;
use Mojo::IOLoop;
use List::Util qw(any);
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

sub dispatch ($self, $msg)
{
	my ($channel, $line) = $msg->{params}->@*;
	my $is_private = $channel !~ /^\#/;

	my $conf = $self->config;
	return unless ($is_private && $channel eq $conf->{nick})
		|| (!$is_private && any { $_ eq $channel } split /,/, $conf->{channel});

	my ($user) = $msg->{prefix} =~ /^(\w+)/;

	my $for_me = !!0;
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
}

sub connect ($self)
{
	$self->irc_instance->connect(sub ($irc, $err) {
		say 'connected';
		warn $err if $err;
	});
}

