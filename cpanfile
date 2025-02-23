requires 'Mojolicious';
requires 'Cpanel::JSON::XS';
requires 'Env::Dot';
requires 'Mooish::Base';

requires 'Mojo::IRC';
requires 'IO::Socket::SSL';

requires 'all';
requires 'Data::ULID';
requires 'Log::Dispatch';

requires 'Rose::DB::Object';
requires 'DBD::Pg';
requires 'DBD::SQLite';

on test => sub {
	requires 'Test2::V0';
};

# vim: ft=perl

