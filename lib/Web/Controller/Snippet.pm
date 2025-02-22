package Web::Controller::Snippet;

use v5.40;

use Mooish::Base;
use Bot::Schema::Snippet;
use Time::Piece;

extends 'Mojolicious::Controller';

has field 'snippet_lifetime' => (
	isa => PositiveInt,
	default => sub { $ENV{KRUK_SNIPPET_LIFETIME} * 60 },
);

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

