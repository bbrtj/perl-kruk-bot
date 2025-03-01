package Bot::AITool::SaveUserNote;

use v5.40;

use Mooish::Base;

use Bot::I18N;

extends 'Bot::AITool';

use constant name => 'save_user_note';

sub _build_definition ($self)
{
	return {
		name => $self->name,
		description =>
			q{Save a note about the user for later. Use spontaneously when you make an observation about the user or the user tells you an interesting fact about them.},
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
	$ctx->add_to_response(_t 'tool.save_user_note.msg.info');
	$self->bot_instance->notes->store($input->{note}, aspect => $ctx->user, reason => 'ai');
	return 'saved';
}

