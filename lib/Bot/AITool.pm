package Bot::AITool;

use v5.40;

use Mooish::Base;

has param 'bot_instance' => (
	isa => InstanceOf ['Bot'],
	weak_ref => 1,
);

has field 'definition' => (
	isa => HashRef,
	lazy => 1,
);

sub name
{
	...
}

sub _build_definition ($self)
{
	...
}

sub runner ($self, $channel, $user, $input)
{
	...
}

sub available ($self)
{
	return !!1;
}

sub register ($class, $bot, %args)
{
	return ($class->name => $class->new(%args, bot_instance => $bot));
}

