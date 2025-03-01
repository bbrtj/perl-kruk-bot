package Bot::AITool::SaveSelfNote;

use v5.40;

use Mooish::Base;

use Bot::I18N;

extends 'Bot::AITool';

use constant name => 'save_self_note';

sub _build_definition ($self)
{
	return {
		name => $self->name,
		description =>
			q{Save an important note about yourself, the chatbot. Use this when the user asks you to remember something about yourself.},
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
	$ctx->add_to_response(_t 'tool.save_self_note.msg.info');
	$self->bot_instance->notes->store($input->{note}, reason => 'ai');
	return 'saved';
}

