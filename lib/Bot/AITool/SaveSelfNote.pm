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
			q{Save a note about yourself for later. Only save important information - will serve as your diary for later. Don't store information about the user here.},
		input_schema => {
			type => 'object',
			required => ['note'],
			properties => {
				note => {
					type => 'string',
					description => 'A note about you, the chatbot',
				},
			},
		},
	};
}

sub runner ($self, $ctx, $input)
{
	$ctx->add_to_response("doodling");
	$self->bot_instance->notes->store($input->{note}, reason => 'ai');
	return 'saved';
}

