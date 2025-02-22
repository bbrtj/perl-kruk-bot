package Bot::DB;

use v5.40;

use parent 'Rose::DB';

__PACKAGE__->use_private_registry;

__PACKAGE__->register_db(
	domain => 'default',
	type => 'default',
	driver => $ENV{DB_ENGINE},
	database => $ENV{DB_DATABASE},
	host => $ENV{DB_HOST},
	port => $ENV{DB_PORT},
	username => $ENV{DB_USER},
	password => $ENV{DB_PASS},
	(lc $ENV{DB_ENGINE} eq 'sqlite' ? (sqlite_unicode => 1) : ()),
);

