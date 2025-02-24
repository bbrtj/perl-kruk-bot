package Bot::Conversation;

use v5.40;

use Mooish::Base;
use Bot::Conversation::Config;

has param 'config' => (
	isa => InstanceOf ['Bot::Conversation::Config'],
);

has param 'conversation_lifetime' => (
	isa => PositiveInt,
);

has field 'first_message_at' => (
	isa => PositiveInt,
	default => sub { time },
	writer => -hidden,
);

has field 'last_message_at' => (
	isa => PositiveInt,
	default => sub { time },
	writer => -hidden,
);

has field 'messages' => (
	isa => ArrayRef [Tuple [Str, ArrayRef]],
	default => sub { [] },
);

sub add_message ($self, $role, $message)
{
	my $msgs = $self->messages;

	if (!ref $message) {
		$message = {
			type => 'text',
			text => $message,
		};
	}

	if (@$msgs && $msgs->[-1][0] eq $role) {
		push $msgs->[-1][1]->@*, $message;
	}
	else {
		push $msgs->@*, [$role, [$message]];
		splice $msgs->@*, 0, -1 * $self->config->history_size * 2;
	}

	$self->_set_last_message_at(time);
	return $self;
}

sub expired ($self)
{
	return time > $self->last_message_at + $self->conversation_lifetime * 60;
}

sub clear ($self)
{
	$self->messages->@* = ();
	$self->_set_last_message_at(time);
	$self->_set_first_message_at(time);
}

sub api_call_format_messages ($self)
{
	return [map { +{role => $_->[0], content => $_->[1]} } $self->messages->@*];
}

