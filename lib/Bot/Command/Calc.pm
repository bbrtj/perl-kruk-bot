package Bot::Command::Calc;

use v5.40;

use Mooish::Base;
use IPC::Open3;
use Symbol qw(gensym);

use Bot::I18N;

extends 'Bot::Command';

use constant name => 'calc';
use constant syntax => _t 'command.calc.help.syntax';

sub description ($self)
{
	my ($code, $out, $err) = $self->_run_tool('--help');

	if ($code != 0) {
		$self->bot_instance->log->debug($err);
		return _t 'command.calc.help.description';
	}
	else {
		# remove usage up to the operators part
		$out =~ s/^.+?operators://si;
		return _t 'command.calc.help.description_with_syntax', $out;
	}
}

sub available ($self)
{
	return -x 'tools/calc';
}

# calc tool compiled from https://github.com/bbrtj/pascal-pn
sub _run_tool ($self, @params)
{
	my $pid = open3(undef, my $stdout, my $stderr = gensym, 'tools/calc', @params);
	waitpid $pid, 0;
	my $code = $? >> 8;

	local $/;
	my $out = readline $stdout;
	my $err = readline $stderr;

	$out =~ s/\v+$//;
	$err =~ s/\v+$//;

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

