package Bot::Command::Calc;

use v5.40;

use Mooish::Base;
use IPC::Open3;
use Symbol qw(gensym);

extends 'Bot::Command';

use constant name => 'calc';
use constant syntax => '[<expression>]';

sub description ($self)
{
	my ($code, $out, $err) = $self->_run_tool('--help');
	my $desc = 'evaluate a mathematical expression';

	if ($code != 0) {
		$self->bot_instance->log->debug($err);
		return $desc;
	}

	return "$desc: ```$out```";
}

# cli tool compiled from https://github.com/bbrtj/pascal-pn
sub _run_tool ($self, @params)
{
	my $pid = open3(undef, my $stdout, my $stderr = gensym, 'tools/cli', @params);
	waitpid $pid, 0;
	my $code = $? >> 8;

	local $/;
	my $out = readline $stdout;
	my $err = readline $stderr;

	chomp $out;
	chomp $err;

	return ($code, $out, $err);
}

sub run ($self, $ctx, @args)
{
	die $self->bad_arguments unless @args;
	my $expr = join ' ', @args;

	my ($code, $out, $err) = $self->_run_tool('-p', $expr);

	if ($code == 0) {
		return $out;
	}
	else {
		die {hint => $err};
	}

}

