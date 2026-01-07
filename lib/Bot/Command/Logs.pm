package Bot::Command::Logs;

use v5.40;

use Mooish::Base;

use Bot::I18N;
use Web;

extends 'Bot::Command';

has field 'web_instance' => (
	isa => InstanceOf ['Web'],
	default => sub { Web->new },
);

use constant name => 'logs';
use constant syntax => _t 'command.logs.help.syntax';
use constant description => _t 'command.logs.help.description';

sub run ($self, $ctx, $channel = $ctx->channel, $hours = 24, @args)
{
	die {hint => _t 'command.logs.err.bad_channel'}
		unless defined $channel;

	die {hint => _t 'command.logs.err.bad_offset', $ENV{KRUK_LOG_LIFETIME} * 24}
		unless $hours > 0 && $hours <= $ENV{KRUK_LOG_LIFETIME} * 24;

	die $self->bad_arguments if @args;

	my $offset = time - int($hours) * 60 * 60;

	return $self->web_instance->url_for(logs => {channel => $channel, from => $offset})->to_string;
}

