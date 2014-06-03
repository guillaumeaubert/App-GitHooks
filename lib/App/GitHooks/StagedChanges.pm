package App::GitHooks::StagedChanges;

use strict;
use warnings;

# External dependencies.
use Carp qw( croak );
use Data::Dumper;
use Data::Validate::Type;
use File::Basename qw();
use File::Slurp qw();
use Parallel::ForkManager qw();
use Try::Tiny;

# Internal dependencies.
use App::GitHooks::Constants qw( :PLUGIN_RETURN_CODES );


=head1 NAME

App::GitHooks::StagedChanged - Staged changes in git.


=head1 VERSION

Version 1.0.6

=cut

our $VERSION = '1.0.6';


=head1 METHODS

=head2 new()

Instantiate a new C<App::GitHooks::StagedChanges> object.

	my $staged_changes = App::GitHooks::StagedChanges->new(
		app => $app,
	);

Arguments:

=over 4

=item * app I<(mandatory)>

An C<App::GitHook> instance.

=back

=cut

sub new
{
	my ( $class, %args ) = @_;
	my $app = delete( $args{'app'} );

	# Check arguments.
	croak 'An "app" argument is mandatory'
		if !Data::Validate::Type::is_instance( $app, class => 'App::GitHooks' );

	return bless(
		{
			app => $app,
		},
		$class,
	);
}


=head2 get_app()

Return the parent C<App::GitHooks> object.

	my $app = $staged_changes->get_app();

=cut

sub get_app
{
	my ( $self ) = @_;

	return $self->{'app'};
}


=head2 verify()

Verify the changes that are being committed, and return information on
whether the checks passed or failed.

	my $checks_pass = $staged_changes->verify(
		use_colors   => $use_colors, # default 1
		app          => $app,
	);

=cut

sub verify
{
	my ( $self, %args ) = @_;
	my $app = delete( $args{'app'} );
	my $failure_character = $app->get_failure_character();
	my $repository = $app->get_repository();
	$app->use_colors( $args{'use_colors'} )
		if defined( $args{'use_colors'} );

	$self->analyze_changes();

	# Check the changed files.
	return $self->check_changed_files();
}


=head2 check_changed_files()

Verify that the files changed pass various rules. Return a boolean indicating
if all the files pass (true) or fail (false) the tests.

	my $all_files_pass = check_changed_files();

=cut

sub check_changed_files
{
	my ( $self ) = @_;
	my $app = $self->get_app();
	my $repository = $app->get_repository();

	# Get a list of changes from Git.
	my @changes = $repository->run( 'diff', '--cached', '--name-status', '--', '.' );

	# Parse changes.
	my $files = {};
	foreach my $change ( @changes )
	{
		my ( $git_action, $file ) = ( $change =~ /^(\w+)\s+(.*)$/x );
		if ( !defined( $file ) )
		{
			print $app->wrap( "Could not parse git diff output:\n$change\n" );
			return 0;
		}

		$files->{ $file } = $git_action;
	}

	#  Check each file.
	my $allow_commit = 1;
	my $total = scalar( keys %$files );
	my $count = 1;
	foreach my $file ( sort keys %$files )
	{
		my $file_passes = $self->check_file(
			file       => $file,
			git_action => $files->{ $file },
			total      => $total,
			count      => $count,
		);
		$allow_commit &&= $file_passes;
		$count++;
	}

	return $allow_commit;
}


=head2 check_file()

Verify that that a given file passes all the verification rules.

	my $file_passes = check_file( $file );

=cut

sub check_file ## no critic (Subroutines::ProhibitExcessComplexity)
{
	my ( $self, %args ) = @_;
	my $file = delete( $args{'file'} );
	my $git_action = delete( $args{'git_action'} );
	my $total = delete( $args{'total'} );
	my $count = delete( $args{'count'} );
	my $app = $self->get_app();
	my $repository = $app->get_repository();

	print $app->wrap( $app->color( 'blue', "($count/$total) $file" ) . "\n" );

	# Skip symlinks.
	if ( -l $repository->work_tree . '/' . $file )
	{
		print $app->wrap(
			$app->color( 'bright_black', "- Skipping symlink." ) . "\n",
			'    ',
		);
		return 1;
	}

	# Skip directories if needed.
	my $config = $app->get_config();
	my $skip_directories = $config->get_regex( '_', 'skip_directories' );
	if ( defined( $skip_directories ) && ( $file =~ /$skip_directories/ ) )
	{
		print $app->wrap(
			$app->color( 'bright_black', "- Skipping excluded directory." ) . "\n",
			'    ',
		);
		return 1;
	}

	# If the file has no extension, try to determine it based on the first line
	# (except for deleted files).
	my $match_file = $file;
	if ( $git_action ne 'D' )
	{
		my ( undef, undef, $extension ) = File::Basename::fileparse( $file, qr/(?<=\.)[^\.]*$/ );
		if ( !defined( $extension ) || $extension eq '' )
		{
			open( my $fh, '<', $file ) || croak "Can't open file $file: $!";
			my $first_line = <$fh>;
			close( $fh );
			# TODO: generalize to other file types.
			$match_file .= '.pl' if defined( $first_line ) && ( $first_line =~ /^#!.*perl/ );
		}
	}

	# Find all the tests we will need to run on the file.
	# Use an arrayref here instead of a hashref, to preserve test order.
	my $tests = [];

	my $plugins = $app->get_plugins( 'pre-commit-file' );
	foreach my $plugin ( @$plugins )
	{
		my $pattern = $plugin->get_file_pattern( app => $app );
		next if $match_file !~ $pattern;
		push(
			@$tests,
			$plugin,
		);
	}

	return 1
	  if scalar( @$tests ) == 0;

	# Run the checks in parallel.
	my $ordered_output = $self->run_parallelized_checks(
		tests      => $tests,
		file       => $file,
		git_action => $git_action,
	);

	# If the file has been deleted and all the checks were skipped, print a
	# short message instead.
	if ( ( $git_action eq 'D' )
		&& ( scalar( grep { $_->{'return_value'} != $PLUGIN_RETURN_SKIPPED } @$ordered_output ) == 0 )
	)
	{
		print $app->wrap(
			$app->color( 'bright_black', "- Skipping deleted file." ) . "\n",
			'    ',
		);
		return 1;
	}
	# Otherwise, display all the information.
	else
	{
		foreach my $output ( @$ordered_output )
		{
			print $self->format_check_output( $output );
		}
	}

	# Determine if the file passed all the checks or not.
	my $file_passes = 1;
	foreach my $output ( @$ordered_output )
	{
		my $return_value = $output->{'return_value'};
		next if $return_value == $PLUGIN_RETURN_PASSED || $return_value == $PLUGIN_RETURN_SKIPPED;
		$file_passes = 0;
		last;
	}

	return $file_passes;
}


=head2 run_parallelized_checks()

Run in parallel the checks for a given file.

	run_parallelized_checks(
		tests	  => $tests,
		file	   => $file,
		git_action => $git_action,
	);

Arguments:

=over 4

=item * tests

An arrayref of tests to run.

=item * file

The path of the file being checked.

=item * git_action

The type of action recorded by git on the file (deletion, addition, etc).

=back

=cut

sub run_parallelized_checks
{
	my ( $self, %args ) = @_;
	my $tests = delete( $args{'tests'} );
	my $file = delete( $args{'file'} );
	my $git_action = delete( $args{'git_action'} );
	my $app = $self->get_app();

	# Configure the fork manager.
	my $fork_manager = Parallel::ForkManager->new(4);

	# Add a hook to determine whether the file passed all the checks.
	my $ordered_output = [];
	$fork_manager->run_on_finish(
		sub
		{
			my ( $pid, $exit_code, $ident, $exit_signal, $core_dump, $data_structure_reference ) = @_;
			croak 'Invalid check return: ' . Dumper( $data_structure_reference )
				if !defined( $data_structure_reference );

			# Store the output. There is no guaranteed order in which the
			# sub-processes will complete, but we want to keep their final
			# output in the order they were listed in the patterns. To achieve
			# that, we store them in an array that we'll display once all the
			# sub-processes have completed.
			my $counter = delete( $data_structure_reference->{'counter'} );
			$ordered_output->[ $counter ] = $data_structure_reference;
		}
	);

	my $method = 'run_' . $app->get_hook_name() . '_file';
	$method =~ s/-/_/g;

	# Run the checks.
	my $counter = -1;
	foreach my $test ( @$tests )
	{
		my $name = $test->get_file_check_description();
		$counter++;

		# Start a parallel process to execute this iteration of the loop.
		my $pid = $fork_manager->start() && next;

		# Execute the check.
		my ( $return_value, $error_message ) = try
		{
			return (
				$test->$method(
					file       => $file,
					git_action => $git_action,
					app        => $app,
				),
				undef,
			);
		}
		catch
		{
			chomp( $_ );
			return ( $PLUGIN_RETURN_FAILED, $_ );
		};

		# Terminate the parallel process and report back to the parent.
		$fork_manager->finish(
			0, # Exit code, not used.
			{
				name          => $name,
				return_value  => $return_value // '',
				error_message => $error_message,
				counter       => $counter,
			}
		);
	}

	# Make sure all the checks have been completed, before we move to the next
	# file.
	$fork_manager->wait_all_children();

	return $ordered_output;
}


=head2 format_check_output()

Format the output of a check against a file into a printable string.

	format_check_output(
		app  => $app,
		data =>
		{
			name          => $name,
			return_value  => $return_value,
			error_message => $error_message,
		}
	);

=cut

sub format_check_output
{
	my ( $self, $data ) = @_;
	my $app = $self->get_app();

	my $name = $data->{'name'};
	my $return_value = $data->{'return_value'};
	my $error_message = $data->{'error_message'};

	my $failure_character = $app->get_failure_character();
	my $success_character = $app->get_success_character();

	# Format the output.
	my $output = '';
	if ( $return_value == $PLUGIN_RETURN_FAILED )
	{
		# The check failed.
		$output .= $app->wrap(
			$app->color( 'red', $failure_character ) . $app->color( 'bright_black', " $name" ) . "\n",
			"    ",
		);
		$return_value .= "\n" if $return_value !~ /\n\Z/;
		$error_message //= '(no error message specified)';
		chomp( $error_message );
		$output .= $app->wrap( $error_message, "        " ) . "\n";
	}
	elsif ( $return_value == $PLUGIN_RETURN_PASSED )
	{
		# The check passed.
		$output .= $app->wrap(
			$app->color( 'green', $success_character ) . $app->color( 'bright_black', " $name" ) . "\n",
			"    ",
		);
	}
	elsif ( $return_value == $PLUGIN_RETURN_SKIPPED )
	{
		# The check was skipped.
		$output .= $app->wrap(
			$app->color( 'bright_black', "- $name" ) . "\n",
			"    ",
		);
	}
	else
	{
		# The check sent an invalid return value.
		$output .= $app->wrap(
			$app->color( 'red', $failure_character ) . $app->color( 'bright_black', " $name" ) . "\n",
			"    ",
		);
		$output .= $app->wrap( "Invalid return value >$return_value<, contact the maintainer.", "        " );
	}

	return $output;
}


=head2 analyze_changes()

Analyze the state of the repository to detect if the changes correspond to a
merge or revert operation.

	$staged_changes->analyze_changes();

=cut

sub analyze_changes
{
	my ( $self ) = @_;
	my $app = $self->get_app();
	my $repository = $app->get_repository();

	# Detect merges.
	$self->{'is_merge'} = -e ( $repository->work_tree() . '/.git/MERGE_MSG' ) ? 1 : 0;

	# Detect reverts.
	$self->{'is_revert'} = 0;
	if ( $self->{'is_merge'} )
	{
		my $merge_message = File::Slurp::read_file( $repository->work_tree() . '/.git/MERGE_MSG' );
		$self->{'is_revert'} = 1
			if $merge_message =~ /^Revert\s/;
	}

	return;
}


=head2 is_revert()

Return true if the changes correspond to a C<git revert> operation, false
otherwise.

	my $is_revert = $staged_changes->is_revert();

=cut

sub is_revert
{
	my ( $self ) = @_;

	$self->analyze_changes()
		if !defined( $self->{'is_revert'} );

	return $self->{'is_revert'};
}


=head2 is_merge()

Return true if the changes correspond to a C<git revert> operation, false
otherwise.

	my $is_merge = $staged_changes->is_merge();

=cut

sub is_merge
{
	my ( $self ) = @_;

	$self->analyze_changes()
		if !defined( $self->{'is_merge'} );

	return $self->{'is_merge'};
}


=head1 BUGS

Please report any bugs or feature requests through the web interface at
L<https://github.com/guillaumeaubert/App-GitHooks/issues/new>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc App::GitHooks::StagedChanges


You can also look for information at:

=over

=item * GitHub's request tracker

L<https://github.com/guillaumeaubert/App-GitHooks/issues>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/app-githooks>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/app-githooks>

=item * MetaCPAN

L<https://metacpan.org/release/App-GitHooks>

=back


=head1 AUTHOR

L<Guillaume Aubert|https://metacpan.org/author/AUBERTG>,
C<< <aubertg at cpan.org> >>.


=head1 COPYRIGHT & LICENSE

Copyright 2013-2014 Guillaume Aubert.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License version 3 as published by the Free
Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see http://www.gnu.org/licenses/

=cut

1;
