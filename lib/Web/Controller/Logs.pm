package Web::Controller::Logs;

use v5.40;

use Mooish::Base;
use Bot::Schema::Log;
use Bot::Logs;
use Time::Piece;
use Mojo::IOLoop;

extends 'Mojolicious::Controller';

has field 'log_lifetime' => (
	isa => PositiveInt,
	default => sub { $ENV{KRUK_LOG_LIFETIME} * 60 * 60 * 24 },
);

sub BUILD ($self, $)
{
	Mojo::IOLoop->singleton->recurring(
		3600 => sub {
			my $threshold = time - $self->snippet_lifetime;

			my $expired = Bot::Schema::Log::Manager->get_logs(
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

sub show ($self)
{
	my $channel = $self->stash('channel');
	my $from = $self->stash('from');

	my $logs = Bot::Logs->new;
	my $items = $logs->retrieve($channel, $from, time);

	my @messages;
	foreach my $item ($items->@*) {
		my $date = Time::Piece->new($item->created_at)->strftime('%F %H:%M:%S');
		my $user = $item->username;
		my $msg = $item->message;
		chomp $msg;

		push @messages, "$date | $user: $msg\n";
	}

	$self->render(
		template => 'logs/show',
		channel => $channel,
		messages => \@messages,
	);
}

