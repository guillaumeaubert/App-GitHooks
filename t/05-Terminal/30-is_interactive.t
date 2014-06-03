#!perl

use strict;
use warnings;

use App::GitHooks::Terminal;
use Test::Exception;
use Test::FailWarnings -allow_deps => 1;
use Test::Git;
use Test::More;
use Test::Type;


# Require git.
has_git( '1.5.0' );
plan( tests => 3 );

can_ok(
	'App::GitHooks::Terminal',
	'is_interactive',
);

ok(
	my $terminal = App::GitHooks::Terminal->new(),
	'Instantiate a new object.',
);

my $interactive;
lives_ok(
	sub
	{
		$interactive = $terminal->is_interactive();
	},
	'Test if the terminal is interactive.',
);

note( 'Current terminal ' . ( $interactive ? 'is' : 'is not' ) . ' interactive.' );
