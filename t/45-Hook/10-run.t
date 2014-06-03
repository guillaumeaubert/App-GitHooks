#!/usr/bin/env perl

use strict;
use warnings;

# Internal dependencies.
use App::GitHooks::Constants qw( :HOOK_EXIT_CODES );
use App::GitHooks::Hook;
use App::GitHooks;

# External dependencies.
use Test::Exception;
use Test::FailWarnings -allow_deps => 1;
use Test::Git;
use Test::More;


# Require git.
has_git( '1.5.0' );
plan( tests => 5 );

can_ok(
	'App::GitHooks::Hook',
	'run',
);

ok(
	push( @{ $App::GitHooks::HOOK_NAMES }, 'test-hook-name' ),
	'Add testing hook name.',
);

ok(
	defined(
		my $app = App::GitHooks->new(
			arguments => undef,
			name      => 'test-hook-name',
		)
	),
	'Instantiate a new App::GitHooks object.',
);

my $return;
lives_ok(
	sub
	{
		$return = App::GitHooks::Hook->run(
			app => $app,
		);
	},
	'Call run().',
);

is(
	$return,
	$HOOK_EXIT_SUCCESS,
	'The hook handler executed successfully.',
);
