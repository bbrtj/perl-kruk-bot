#!/usr/bin/env perl
# HARNESS-NO-PRELOAD
# HARNESS-CAT-LONG

# running this requires App::Yath installed globally
# due to a bug, carmel must be rolled out to run it

use strict;
use warnings;

use lib 'lib';
use App::Yath::Util qw/find_yath/;
use Env qw(@PERL5LIB);

unshift @PERL5LIB, 'lib';

$ENV{DB_ENGINE} = 'SQLite';
$ENV{DB_DATABASE} = 'test.db';

system($^X, find_yath(), '-D', 'test', '--default-search' => './t', '--default-search' => './t2', @ARGV);
exit $?;

