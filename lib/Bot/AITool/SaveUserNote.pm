package Bot::AITool::SaveUserNote;

use v5.40;

use Mooish::Base;

extends 'Bot::AITool';

use constant name => 'save_user_note';

sub _build_definition ($self)
{
	return {
		name => $self->name,
		description =>
			q{Save a note about the user for later. Don't wait for user to tell you to remember something, use it if they share something that may help with conversation.},
		input_schema => {
			type => 'object',
			required => ['note'],
			properties => {
				note => {
					type => 'string',
					description => 'A note about the user',
				},
			},
		},
	};
}

sub runner ($self, $ctx, $input)
{
	$ctx->add_to_response("noting down");
	$self->bot_instance->notes->store($input->{note}, aspect => $ctx->user, reason => 'ai');
	return 'saved';
}

