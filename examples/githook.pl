#!/usr/bin/env perl

use strict;
use warnings;

use App::GitHooks;

App::GitHooks->run(
    name      => $0,
    arguments => \@ARGV,
);
