package Bot::AITool::ReadChat;

use v5.40;

use Moo;
use Mooish::AttributeBuilder;
use Types::Common -types;

extends 'Bot::AITool';

use constant name => 'read_chat';

sub _build_definition ($self)
{
	return {
		name => $self->name,
		description  => q{Get everyone's messages in this chat room.},
		input_schema => {
			type => 'object',
		},
	};
}

sub runner ($self, $channel, $user, $input)
{
	return join "\n",
		map { "$_->[0] said: $_->[1]" }
		$self->bot_instance->observed_messages->{$channel}->@*;
}

