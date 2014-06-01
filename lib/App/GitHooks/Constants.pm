package App::GitHooks::Constants;

use strict;
use warnings;

# External dependencies.
use base 'Exporter';


=head1 NAME

App::GitHooks::Constants - Constants used by various modules in the App::GitHooks namespace.


=head1 VERSION

Version 1.0.3

=cut

our $VERSION = '1.0.3';


=head1 VARIABLES

=head2 Plugin return values

=over 4

=item * C<$PLUGIN_RETURN_FAILED>

Indicates that the checks performed by the plugin did not pass.

=item * C<$PLUGIN_RETURN_SKIPPED>

Indicates that the checks performed by the plugin were skipped.

=item * C<$PLUGIN_RETURN_PASSED>

Indicates that the checks performed by the plugin passed.

=back

=cut

our $PLUGIN_RETURN_FAILED = -1;
our $PLUGIN_RETURN_SKIPPED = 0;
our $PLUGIN_RETURN_PASSED = 1;


=head2 Hook exit codes

=over 4

=item * C<$HOOK_EXIT_SUCCESS>

Indicates that the hook executed successfully.

=item * C<$HOOK_EXIT_FAILURE>

Indicates that the hook failed to execute correctly.

=back

=cut

our $HOOK_EXIT_SUCCESS = 0;
our $HOOK_EXIT_FAILURE = 1;


=head1 EXPORT TAGS

=over 4

=item * C<:PLUGIN_RETURN_CODES>

Exports C<$PLUGIN_RETURN_FAILED>, C<$PLUGIN_RETURN_SKIPPED>, and C<$PLUGIN_RETURN_PASSED>.

=item * C<:HOOK_EXIT_CODES>

Exports C<$HOOK_EXIT_SUCCESS>, C<$HOOK_EXIT_FAILURE>.

=back

=cut

# Exportable variables.
our @EXPORT_OK = qw(
	$PLUGIN_RETURN_FAILED
	$PLUGIN_RETURN_SKIPPED
	$PLUGIN_RETURN_PASSED
	$HOOK_EXIT_SUCCESS
	$HOOK_EXIT_FAILURE
);

# Exported tags.
our %EXPORT_TAGS =
(
	PLUGIN_RETURN_CODES =>
	[
		qw(
			$PLUGIN_RETURN_FAILED
			$PLUGIN_RETURN_SKIPPED
			$PLUGIN_RETURN_PASSED
		)
	],
	HOOK_EXIT_CODES     =>
	[
		qw(
			$HOOK_EXIT_SUCCESS
			$HOOK_EXIT_FAILURE
		)
	],
);


=head1 BUGS

Please report any bugs or feature requests through the web interface at
L<https://github.com/guillaumeaubert/App-GitHooks/issues/new>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc App::GitHooks::Constants


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
