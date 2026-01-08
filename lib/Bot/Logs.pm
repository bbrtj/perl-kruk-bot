package Bot::Logs;

use v5.40;

use Mooish::Base;
use Bot::Schema::Log;

sub store ($self, $channel, $username, $message)
{
	my $item = Bot::Schema::Log->new(
		channel => $channel,
		username => $username,
		message => $message,
	);

	$item->prepare_and_save;
	return $item->id;
}

sub retrieve ($self, $channel, $from, $to)
{
	return Bot::Schema::Log::Manager->get_logs(
		query => [
			channel => $channel,
			created_at => {lt => $to},
			and => [
				created_at => {gt => $from},
			],
		],
		sort_by => 'created_at ASC',
	);
}

