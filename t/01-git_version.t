#!perl

use strict;
use warnings;

use Test::FailWarnings -allow_deps => 1;
use Test::Git;
use Test::More;


has_git();

plan( tests => 2 );

use_ok('Git::Repository');

ok(
	defined(
		my $git_version = Git::Repository->version()
	),
	'Retrieve the git version.',
);
$git_version //= '(undef)';

diag( 'Using git version ' . $git_version . '.' );
