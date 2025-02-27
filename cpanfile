requires 'Mojolicious';
requires 'Cpanel::JSON::XS';
requires 'Env::Dot';
requires 'Mooish::Base';

requires 'Mojo::IRC';
requires 'IO::Socket::SSL';

requires 'all';
requires 'Data::ULID';
requires 'Log::Dispatch';
requires 'HTML::FormatText';
requires 'Regexp::Common';

requires 'Rose::DB::Object';
requires 'DBD::Pg';
requires 'DBD::SQLite';

requires 'Data::Localize';
requires 'Data::Localize::YAML';
requires 'Data::Localize::Format::Sprintf';

on test => sub {
	requires 'Test2::V0';
};

# vim: ft=perl

