#!/usr/bin/env perl

use v5.40;
use Mojo::File qw(curfile);
use lib curfile->dirname->dirname->child('lib')->to_string;

use Env::Dot;
use Web;

Web->new->start;

