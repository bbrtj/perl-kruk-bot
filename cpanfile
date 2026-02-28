requires 'Mojolicious';
requires 'Mojo::IRC';
requires 'IO::Socket::SSL';

requires 'Mooish::Base';
requires 'Env::Dot';
requires 'all';
requires 'Data::ULID';
requires 'Log::Dispatch';
requires 'HTML::FormatText';
requires 'Regexp::Common';

requires 'Rose::DB::Object';
requires 'DBD::Pg';
requires 'DBD::SQLite';

requires 'Cpanel::JSON::XS';
requires 'YAML::PP';

requires 'Storage::Abstract' => '0.008';

on test => sub {
	requires 'Test2::V0';
};

# vim: ft=perl

