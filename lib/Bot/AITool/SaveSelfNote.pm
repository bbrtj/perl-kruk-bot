package Bot::AITool::SaveSelfNote;

use v5.40;

use Mooish::Base;

extends 'Bot::AITool';

use constant name => 'save_self_note';

sub _build_definition ($self)
{
	return {
		name => $self->name,
		description =>
			q{Save a note about yourself for later (global for all users). Only save important information - will serve as your diary for later.},
		input_schema => {
			type => 'object',
			required => ['note', 'reason'],
			properties => {
				note => {
					type => 'string',
					description => 'A note about you, the chatbot',
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
	$ctx->add_to_response("noting down") if $input->{reason} eq 'requested';
	$self->bot_instance->notes->store($input->{note}, reason => $input->{reason});
	return 'saved';
}

