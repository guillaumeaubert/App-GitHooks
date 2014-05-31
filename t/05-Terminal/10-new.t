#!perl

use strict;
use warnings;

use App::GitHooks::Terminal;
use Test::Exception;
use Test::FailWarnings -allow_deps => 1;
use Test::More tests => 3;
use Test::Type;


can_ok(
	'App::GitHooks::Terminal',
	'new',
);

my $terminal;
lives_ok(
	sub
	{
		$terminal = App::GitHooks::Terminal->new();
	},
	'Instantiate a new object.',
);

ok_instance(
	$terminal,
	name  => 'Terminal object',
	class => 'App::GitHooks::Terminal',
);
