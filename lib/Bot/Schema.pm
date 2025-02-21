package Bot::Schema;

use v5.40;

use Bot::DB;
use parent 'Rose::DB::Object';

use Rose::DB::Object::Helpers qw(column_value_pairs);

sub init_db
{
	Bot::DB->new_or_cached;
}

