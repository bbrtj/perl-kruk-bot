package Web;

use v5.40;

use Mooish::Base;
use Mojo::URL;

extends 'Mojolicious';

has field 'base_url' => (
	isa => Str,
	default => sub { $ENV{MOJO_HOST} // 'http://localhost:3000' },
);

sub startup ($self)
{
	$self->secrets([$ENV{MOJO_SECRETS}]);
	my $r = $self->routes;

	$r->get('/snippet/:snippet_id')->to('snippet#fetch')->name('snippet');
}

sub url_for ($self, @args)
{
	my $url = $self->build_controller->url_for(@args);
	return $url->to_abs(Mojo::URL->new($self->base_url));
}

