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
		name     => 'Key not defined.',
		config   => '',
		expected => undef,
	},
	{
		name     => 'Empty value.',
		config   => "regex =\n",
		expected => undef,
	},
	{
		name     => 'Value is not a regex.',
		config   => "regex = test\n",
		throws   => q|The key regex in the section _ is not a regex, use /.../ to delimit your expression|,
	},
	{
		name     => 'Value has unescaped slash delimiters.',
		config   => "regex = /test/test/\n",
		throws   => q|The key regex in the section _ does not specify a valid regex, it has unescaped '/' delimiters inside it|,
	},
	{
		name     => 'Valid regex.',
		config   => "regex = /test/\n",
		expected => 'test',
	},
];

# Declare tests.
plan( tests => scalar( @$tests + 1 ) );

# Make sure the function exists before we start.
can_ok(
	'App::GitHooks::Config',
	'get_regex',
);

# Run each test in a subtest.
foreach my $test ( @$tests )
{
	subtest(
		$test->{'name'},
		sub
		{
			plan( tests => 8 );

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

			ok(
				defined(
					my $config = $app->get_config()
				),
				'Retrieve the corresponding config object.',
			);

			my $regex;
			if ( defined( $test->{'throws'} ) )
			{
				throws_ok(
					sub
					{
						$regex = $config->get_regex('_', 'regex');
					},
					qr/\Q$test->{'throws'}\E/,
					'regex() throws the expected error.',
				);
			}
			else
			{
				lives_ok(
					sub
					{
						$regex = $config->get_regex('_', 'regex');
					},
					'Retrieve the regex value.',
				);
			}

			SKIP:
			{
				skip('The regex() call should return an exception.', 1)
					if defined( $test->{'throws'} );

				is(
					$regex,
					$test->{'expected'},
					'The regex returned matches the expected value.',
				);
			}
		}
	);
}
