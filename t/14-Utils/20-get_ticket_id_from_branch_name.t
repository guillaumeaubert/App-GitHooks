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

# Define tests.
my $tests =
[
	{
		name        => 'Missing extract_ticket_id_from_branch from config.',
		config      => '',
		branch_name => 'DEV-123_test',
		expected    => undef,
	},
	{
		name        => 'Extract using extract_ticket_id_from_branch.',
		config      => 'extract_ticket_id_from_branch = /^(DEV-\d+)/' . "\n",
		branch_name => 'DEV-123_test',
		expected    => 'DEV-123',
	},
	{
		name        => 'Extract using extract_ticket_id_from_branch and project_prefixes.',
		config      => 'extract_ticket_id_from_branch = /^($project_prefixes-\d+)/' . "\n"
			. "project_prefixes = DEV, OPS\n",
		branch_name => 'DEV-123_test',
		expected    => 'DEV-123',
	},
	{
		name        => 'Normalize extracted ticket ID.',
		config      => 'extract_ticket_id_from_branch = /^(DEV-?\d+)/' . "\n"
			. 'normalize_branch_ticket_id = s/(DEV)-?(\d+)/DEV-$2/' . "\n",
		branch_name => 'DEV123_test',
		expected    => 'DEV-123',
	},
];

# Declare the number of tests.
plan( tests => scalar( @$tests ) + 1 );

# Make sure the function exists before we start.
can_ok(
	'App::GitHooks::Utils',
	'get_ticket_id_from_branch_name',
);

foreach my $test ( @$tests )
{
	subtest(
		$test->{'name'},
		sub
		{
			plan( tests => 11 );

			# Set up test repository.
			ok(
				defined(
					my $source_directory = Cwd::getcwd(),
				),
				'Retrieve the current directory.',
			);

			ok(
				defined(
					my $repository = test_repository()
				),
				'Create a test git repository.',
			);

			ok(
				chdir $repository->work_tree(),
				'Switch the current directory to the test git repository.',
			);

			# Create a new branch.
			lives_ok(
				sub
				{
					$repository->run( 'checkout', '-b', $test->{'branch_name'} );
				},
				"Create a new branch $test->{'branch_name'}.",
			);

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

			my $ticket_id;
			lives_ok(
				sub
				{
					$ticket_id = App::GitHooks::Utils::get_ticket_id_from_branch_name( $app );
				},
				'Retrieve the ticket ID from the branch name.',
			);

			is(
				$ticket_id,
				$test->{'expected'},
				'Compare the output and expected results.',
			);
		}
	);
}
