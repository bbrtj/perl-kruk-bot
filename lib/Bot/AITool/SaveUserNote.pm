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
			required => ['note', 'reason'],
			properties => {
				note => {
					type => 'string',
					description => 'A note about the user',
				},
				reason => {
					type => 'string',
					enum => ['spontaneous', 'requested'],
					description => 'Use "requested" if user asked you to remember',
				},
			},
		},
	};
}

sub runner ($self, $ctx, $input)
{
	$self->bot_instance->notes->store($input->{note}, aspect => $ctx->user, reason => $input->{reason});
	return 'saved';
}

