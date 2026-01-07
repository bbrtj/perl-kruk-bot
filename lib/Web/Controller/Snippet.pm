package Web::Controller::Snippet;

use v5.40;

use Mooish::Base;
use Bot::Schema::Snippet;
use Time::Piece;
use Mojo::IOLoop;

extends 'Mojolicious::Controller';

has field 'snippet_lifetime' => (
	isa => PositiveInt,
	default => sub { $ENV{KRUK_SNIPPET_LIFETIME} * 60 },
);

sub BUILD ($self, $)
{
	Mojo::IOLoop->singleton->recurring(
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

sub fetch ($self)
{
	my $item = Bot::Schema::Snippet->new(id => $self->stash('snippet_id'));

	if (!$item->load(speculative => !!1)) {
		$self->render(text => 'No such snippet');
		$self->rendered(404);
		return;
	}

	my $timestamp = Time::Piece->new($item->created_at);

	$self->render(
		template => 'snippet/fetch',
		item => $item,
		expiration => $timestamp + $self->snippet_lifetime,
	);
}

