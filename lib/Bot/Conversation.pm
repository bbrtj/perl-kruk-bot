package Bot::Conversation;

use v5.40;

use Mooish::Base;
use Time::Piece;

use Bot::Cache;
use Bot::Conversation::Config;

has param 'config' => (
	isa => InstanceOf ['Bot::Conversation::Config'],
);

has param 'conversation_lifetime' => (
	isa => PositiveInt,
);

has field 'first_message_at' => (
	isa => InstanceOf ['Time::Piece'],
	default => sub { scalar localtime },
	writer => -hidden,
);

has field 'last_message_at' => (
	isa => InstanceOf ['Time::Piece'],
	default => sub { scalar localtime },
	writer => -hidden,
);

has field 'cached_at' => (
	isa => InstanceOf ['Time::Piece'],
	writer => -hidden,
	clearer => -hidden,
);

has field 'messages' => (
	isa => ArrayRef [Tuple [Str, ArrayRef]],
	default => sub { [] },
);

sub set_cached ($self)
{
	$self->_set_cached_at(scalar localtime);
}

sub check_cached ($self)
{
	# extra 5 seconds to make sure the cache is available
	if (defined $self->cached_at && time > $self->cached_at + Bot::Cache->CACHE_LIFETIME - 5) {
		$self->_clear_cached_at;
	}

	return defined $self->cached_at;
}

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
		if (!$self->check_cached) {
			splice $msgs->@*, 0, -1 * $self->config->history_size;
		}
	}

	$self->_set_last_message_at(scalar localtime);
	return $self;
}

sub expired ($self)
{
	return time > $self->last_message_at + $self->conversation_lifetime * 60;
}

sub clear ($self)
{
	$self->messages->@* = ();
	$self->_set_last_message_at(scalar localtime);
	$self->_set_first_message_at(scalar localtime);
}

sub api_call_format_messages ($self)
{
	return [map { +{role => $_->[0], content => $_->[1]} } $self->messages->@*];
}

