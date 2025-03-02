use Rex -feature => [qw(1.4 exec_autodie)];
use Path::Tiny qw(cwd);

use Rex::Config;
use Rex::Commands::PerlSync;

my $system_name = 'kruk';
my $perlbrew_bashrc = $ENV{REMOVE_PERLBREW_BASHRC} // '~/perl5/perlbrew/etc/bashrc';
my $remote_perl = $ENV{REMOTE_PERL} // 'perl-5.40.0';

Rex::Config->set_timeout(10);

desc 'Deploy to production server';
task deploy => sub {
	my $cwd = cwd;
	my $build_dir = "~/$system_name";
	my $modules_changed = !!0;

	say "== Deploying: $cwd ==";

	say 'Creating directory structure...';
	file $build_dir, ensure => 'directory';
	file "$build_dir/previous", ensure => 'absent';
	rename "$build_dir/current", "$build_dir/previous"
		if is_dir "$build_dir/current";
	file "$build_dir/current", ensure => 'directory';

	say 'Uploading files...';
	sync_up $cwd, "$build_dir/current", {
		exclude => [qw(.* .git sqitch* *.db t cpanfile* Rexfile* local tools art)],
	};

	file "$build_dir/$_", source => "$cwd/$_", on_change => sub { $modules_changed = !!1 }
		for qw(cpanfile cpanfile.snapshot);

	say 'Modules status: ' . ($modules_changed ? 'OUTDATED' : 'ok');
	if ($modules_changed) {
		# TODO: move local directory into previous?
		say 'Installing modules...';
		run <<~CARMEL;
			source $perlbrew_bashrc \\
			&& perlbrew use $remote_perl \\
			&& cd $build_dir \\
			&& carmel install \\
			&& carmel rollout
		CARMEL
	}

	say 'Restarting ubic...';
	run "source $perlbrew_bashrc && ubic restart $system_name-irc";
	run "source $perlbrew_bashrc && ubic restart $system_name-web";
};

# ex: ft=perl

