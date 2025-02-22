#!/usr/bin/env perl
# HARNESS-NO-PRELOAD
# HARNESS-CAT-LONG
# THIS IS A GENERATED YATH RUNNER TEST
use strict;
use warnings;

use lib 'lib';
use App::Yath::Util qw/find_yath/;
use Env qw(@PERL5LIB);

unshift @PERL5LIB, 'lib';
unshift @PERL5LIB, 'local/lib/perl5';

$ENV{DB_ENGINE} = 'SQLite';
$ENV{DB_DATABASE} = 'test.db';

system($^X, find_yath(), '-D', 'test', '--default-search' => './t', '--default-search' => './t2', @ARGV);
exit $?;

