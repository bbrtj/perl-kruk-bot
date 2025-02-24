package Bot::AITool::ReadChat;

use v5.40;

use Mooish::Base;

extends 'Bot::AITool';

use constant name => 'read_chat';

sub _build_definition ($self)
{
	return {
		name => $self->name,
		description => q{Get everyone's messages in this chat room.},
		input_schema => {
			type => 'object',
		},
	};
}

sub runner ($self, $ctx, $input)
{
	$ctx->add_to_response("reading chat");

	return "Chat log:\n" . join "\n",
		map { "$_->[0] said: $_->[1]" }
		$self->bot_instance->observed_messages->{$ctx->channel}->@*;
}

sub available ($self, $ctx)
{
	return $ctx->has_channel && scalar $ctx->message =~ /sudo/i;
}

