#!perl

use strict;
use warnings;

use App::GitHooks;
use App::GitHooks::Utils;
use File::Temp;
use Test::Exception;
use Test::FailWarnings -allow_deps => 1;
use Test::Git;
use Test::More;


# Require git.
has_git( '1.7.4.1' );

# List of tests to run.
my $tests =
[
	{
		name     => 'No projects defined.',
		config   => "",
		expected => '',
	},
	{
		name     => 'Space-separated project prefixes.',
		config   => "project_prefixes = OPS DEV\n",
		expected => '(?:OPS|DEV)',
	},
	{
		name     => 'Leading and trailing whitespace.',
		config   => "project_prefixes =    OPS, DEV     \n",
		expected => '(?:OPS|DEV)',
	},
];

# Declare tests.
plan( tests => scalar( @$tests + 1 ) );

# Make sure the function exists before we start.
can_ok(
	'App::GitHooks::Utils',
	'get_project_prefix_regex',
);

# Run each test in a subtest.
foreach my $test ( @$tests )
{
	subtest(
		$test->{'name'},
		sub
		{
			plan( tests => 7 );

			ok(
				my ( $file_handle, $filename ) = File::Temp::tempfile(),
				'Create a temporary file to store the githooks config.',
			);

			ok(
				( print $file_handle $test->{'config'} ),
				'Write the test githooks config.',
			);

			ok(
				close( $file_handle ),
				'Close githooks config file.',
			);

			note( "GITHOOKSRC will be set to $filename." );

			ok(
				local( $ENV{'GITHOOKSRC'} ) = $filename,
				'Set the environment variable GITHOOKSRC to point to the test config.',
			);

			ok(
				defined(
					my $app = App::GitHooks->new(
						arguments => [],
						name      => 'commit-msg',
					)
				),
				'Instantiate a new App::GitHooks object.',
			);

			my $prefixes;
			lives_ok(
				sub
				{
					$prefixes = App::GitHooks::Utils::get_project_prefix_regex( $app );
				},
				'Retrieve the project prefixes.',
			);

			is_deeply(
				$prefixes,
				$test->{'expected'},
				'Compare the output and expected results.',
			) || diag( explain( $prefixes ) );
		}
	);
}
