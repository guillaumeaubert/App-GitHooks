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
		name     => 'No value defined in the config, fall back on the default.',
		config   => "project_prefixes = OPS DEV\n",
		expected => '^((?:OPS|DEV)-\d+|--)\: ',
	},
	{
		name     => 'Value defined in the config.',
		config   => "project_prefixes = OPS DEV\n"
			. 'extract_ticket_id_from_commit = /^($project_prefixes)_(\d+)/' . "\n",
		expected => '^((?:OPS|DEV))_(\d+)',
	},
];

# Declare tests.
plan( tests => scalar( @$tests + 1 ) );

# Make sure the function exists before we start.
can_ok(
	'App::GitHooks::Utils',
	'get_ticket_id_from_commit_regex',
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

			note( "GITHOOKSRC_FORCE will be set to $filename." );

			ok(
				local( $ENV{'GITHOOKSRC_FORCE'} ) = $filename,
				'Set the environment variable GITHOOKSRC_FORCE to point to the test config.',
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

			my $ticket_id_regex;
			lives_ok(
				sub
				{
					$ticket_id_regex = App::GitHooks::Utils::get_ticket_id_from_commit_regex( $app );
				},
				'Retrieve the ticket ID regex.',
			);

			is(
				$ticket_id_regex,
				$test->{'expected'},
				'Compare the output and expected results.',
			);
		}
	);
}
