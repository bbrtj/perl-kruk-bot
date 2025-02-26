package Bot::Command;

use v5.40;

use Mooish::Base;

has param 'bot_instance' => (
	isa => InstanceOf ['Bot'],
	weak_ref => 1,
);

use constant prefix => '.';
use constant alter_prefix => ':';
use constant bad_arguments => {hint => 'invalid command arguments'};
use constant bad_alter_arguments => {hint => 'invalid alter command arguments'};
use constant can_run => !!1;
use constant can_alter => !!0;
use constant available => !!1;

sub run ($self, $ctx, @args)
{
	...;
}

sub alter ($self, $ctx, @args)
{
	...;
}

sub name ($self)
{
	...;
}

sub description ($self)
{
	...;
}

sub syntax ($self)
{
	...;
}

sub get_usage ($self)
{
	return join ' ', grep { length } $self->name, $self->syntax;
}

sub get_full_description ($self)
{
	my $alter = '';
	$alter = ' (' . ($self->can_run ? 'can' : 'must') . ' alter a message)'
		if $self->can_alter;

	return $self->description . $alter;
}

sub register ($class, $bot, %args)
{
	my $self = $class->new(%args, bot_instance => $bot);

	return $self->available ? ($class->name => $self) : ();
}

sub execute ($self, $ctx, $args, $altering)
{
	try {
		if ($altering) {
			if (!$self->can_alter) {
				$ctx->set_response("Command @{[$self->name]} cannot alter a message");
				return;
			}

			$self->alter($ctx, @$args);
		}
		else {
			if (!$self->can_run) {
				$ctx->set_response("Command @{[$self->name]} must alter a message");
				return;
			}

			my $output = $self->run($ctx, @$args);
			$ctx->set_response($output)
				if defined $output;
		}
	}
	catch ($e) {
		my $hint = '';
		if (ref $e eq 'HASH' && $e->{hint}) {
			$hint = ": $e->{hint}";
		}
		else {
			$self->bot_instance->log->debug($e);
		}

		$ctx->set_response("Command error$hint. Usage: " . $self->get_usage);
	}
}

