package Bot::Command::Personality;

use v5.40;

use Mooish::Base;
use List::Util qw(any);

extends 'Bot::Command';

use constant name => 'personality';
use constant syntax => '(switch <name>)';
use constant description => 'show and modify bot personalities (for you)';

sub runner ($self, $ctx, @args)
{
	if (!$args[0]) {
		return $self->info($ctx);
	}
	elsif (@args == 2 && $args[0] eq 'switch' && SimpleStr->check($args[1])) {
		return $self->switch($ctx, $args[1]);
	}

	die $self->bad_arguments;
}

sub list ($self)
{
	return map { /personality\.(\w+)\.ep/; $1 } glob 'prompts/personality.*.ep';
}

sub info ($self, $ctx)
{
	my $current = $self->bot_instance->get_conversation($ctx)->personality;

	return qq{You are currently talking with "$current" bot. Other possible options are: @{[join ', ', $self->list]}};
}

sub switch ($self, $ctx, $personality)
{
	return 'No such personality' unless any { $personality eq $_ } $self->list;
	$self->bot_instance->get_conversation($ctx)->set_personality($personality);
	return 'Personality modified';
}

