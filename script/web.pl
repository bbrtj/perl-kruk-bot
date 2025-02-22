#!/usr/bin/env perl

use v5.40;
use lib 'local/lib/perl5';
use lib 'lib';

use Env::Dot;
use Web;

Web->new->start;

