package Bot::IRC;

use v5.40;

use Mooish::Base;
use Mojo::IRC;
use List::Util qw(any);
use Encode qw(encode decode);

use Bot::Schema::Snippet;
use Bot::Log;
use Web;

use constant MAX_IRC_MESSAGE_LENGTH => 430;
use constant NICK_RE => qr{[^ ,*?!@.:#&~+%][^ ,*?!@.:]*};

has param 'config' => (
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
	default => sub { ($ENV{KRUK_SNIPPET_LIFETIME} // 1440) * 60 },
);

has field 'log' => (
	isa => InstanceOf ['Bot::Log'],
	default => sub {
		Bot::Log->new;
	},
);

sub dispatch ($self, $msg)
{
	my ($channel, $line) = $msg->{params}->@*;
	my $is_private = $channel !~ /^\#/;

	my $conf = $self->config;
	return unless ($is_private && $channel eq $conf->{nick})
		|| (!$is_private && any { $_ eq $channel } split /,/, $conf->{channel});

	my ($user) = $msg->{prefix} =~ /^(@{[NICK_RE]})/;

	my $for_me = $is_private;
	if ($line =~ /^(@{[NICK_RE]}):/) {
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
	if ($snippet !~ /\v/ && length $snippet < 80) {
		return "`$snippet`";
	}

	my $type;
	if ($snippet =~ s{^(\w+)\v}{}) {
		$type = $1;
	}

	my $item = Bot::Schema::Snippet->new(
		syntax => $type,
		snippet => $snippet,
	);

	$item->prepare_and_save;
	return $self->web_instance->url_for(snippet => {snippet_id => $item->id});
}

sub partition_text ($self, $text, $prefix)
{
	# reduce to one line with spaces
	$text =~ s/[\s\v]/ /g;

	# reduce multiple spaces
	$text =~ s/\s+/ /g;

	$text = trim $text;
	my $max_line_length = MAX_IRC_MESSAGE_LENGTH - length(encode 'UTF-8', $prefix) - 1;
	my @lines = (encode 'UTF-8', $text);

	while (length $lines[-1] > $max_line_length) {
		my $length = rindex $lines[-1], ' ', $max_line_length;
		$length = $max_line_length if !$length;
		splice @lines, -1, 0, substr $lines[-1], 0, $length, '';
	}

	return [map { trim decode 'UTF-8', $_ } @lines];
}

sub speak ($self, $ctx)
{
	my $msg = $ctx->full_response;
	my $user = $ctx->user;

	my $prefix = $ctx->has_channel ? ":$user:" : ':';

	$msg =~ s{```(.*?)```}{$self->save_snippet($1)}seg;
	my @lines = $self->partition_text($msg, $prefix)->@*;

	my $irc = $self->irc_instance;
	if ($ctx->has_channel) {
		$irc->write(privmsg => $ctx->channel, ":$user: $_") foreach splice @lines, 0, 5;
		$irc->write(privmsg => $ctx->channel, ":$user: [response was truncated]") if @lines;
	}
	else {
		$irc->write(privmsg => $user, ":$_") foreach @lines;
	}
}

sub configure ($self, $react_sub)
{
	my $irc = $self->irc_instance;

	$irc->on(
		irc_mode => sub ($, $msg) {
			foreach my $channel (split /,/, $self->config->{channel}) {
				$irc->write(join => $channel);
				$self->log->info("joining channel $channel");
			}
		}
	);

	$irc->on(
		irc_join => sub ($, $msg) {
			$self->log->info("joined channel $msg->{params}[0]");
		}
	);

	$irc->on(
		irc_notice => sub ($, $msg) {
			if ($msg->{params}[1] =~ /\/msg nickserv identify/i) {
				$irc->write(ns => 'identify', $self->config->{password});
			}
		}
	);

	$irc->on(
		irc_privmsg => sub ($, $msg) {
			my $msg_data = $self->dispatch($msg);
			return if !$msg_data;

			$react_sub->($msg_data);
		}
	);

	$irc->ioloop->recurring(
		60 => sub {
			my $threshold = time - $self->snippet_lifetime;

			my $expired = Bot::Schema::Snippet::Manager->get_snippets(
				query => [
					created_at => {lt => $threshold},
				],
			);

			foreach my $item (@$expired) {
				$item->delete;
			}
		}
	);
}

sub connect ($self)
{
	$self->irc_instance->connect(
		sub ($irc, $err) {
			$self->log->info('connected');
			warn $err if $err;
		}
	);
}

