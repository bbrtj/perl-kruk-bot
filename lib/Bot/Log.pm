package Bot::Log;

use v5.40;

use Mooish::Base;
use Log::Dispatch;
use Time::Piece;

has param 'logger' => (
	isa => InstanceOf ['Log::Dispatch'],
	lazy => sub ($self) {
		Log::Dispatch->new(outputs => $self->build_config);
	},
	handles => [qw(debug info warning error critical emergency)],
);

has option 'filename' => (
	isa => Str,
);

sub singleton ($class)
{
	state $self = Bot::Log->new(filename => 'bot.log');
	return $self;
}

sub _get_log_callback ($self)
{
	return sub (%params) {
		my $time = localtime;
		my $time_str = $time->ymd . ' ' . $time->hms;

		my $str = "[$time_str]";
		my $level_str = uc $params{level};
		chomp $params{message};
		my $ph = " " x length $str;
		$params{message} =~ s/(\R)/$1$ph\[$level_str] /g;

		return "$str\[$level_str] $params{message}\n";
	};
}

sub _get_screen_callback ($self)
{
	return sub (%params) {
		my $time = localtime;
		my $time_str = $time->hms;

		my $str = "[$time_str]";
		my $level_str = uc $params{level};
		chomp $params{message};
		my $ph = " " x length $str;
		$params{message} =~ s/(\R)/$1$ph\[$level_str] /g;

		return "$str\[$level_str] $params{message}\n";
	};
}

sub build_config ($self)
{
	return [
		[
			'Screen',
			name => 'output',
			stderr => 0,
			min_level => 'debug',
			callbacks => $self->_get_screen_callback,
		],
	] unless $self->has_filename;

	return [
		(
			$ENV{KRUK_PRODUCTION} ? () : (
				[
					'Screen',
					name => 'development debug',
					min_level => 'debug',
					max_level => 'critical',
					stderr => 0,
					callbacks => $self->_get_screen_callback,
				]
			)
		),
		[
			'File::Locked',
			name => 'file',
			min_level => 'warning',
			filename => $self->filename,
			mode => '>>',
			binmode => ":encoding(UTF-8)",
			callbacks => $self->_get_log_callback,
		],
		[
			'Screen',
			name => 'stderr',
			min_level => 'emergency',
			stderr => 1,
			callbacks => $self->_get_log_callback,
		],
	];
}

