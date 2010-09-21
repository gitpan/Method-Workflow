package Method::Workflow::Method;
use strict;
use warnings;

use Exodist::Util qw/ blessed /;
use Carp qw/ croak /;
use base 'Exodist::Util::Sub';

sub workflow { shift->stash->{ workflow }}

1;

=head1 NAME

Method::Workflow::Method - Blessed methods associated weth workflows

=head1 METHODS

=over 4

=item $wf = $method->workflow()

Return the associated workflow.

=back

=head1 FENNEC PROJECT

This module is part of the Fennec project. See L<Fennec> for more details.
Fennec is a project to develop an extensible and powerful testing framework.
Together the tools that make up the Fennec framework provide a potent testing
environment.

The tools provided by Fennec are also useful on their own. Sometimes a tool
created for Fennec is useful outside the greater framework. Such tools are
turned into their own projects. This is one such project.

=over 2

=item L<Fennec> - The core framework

The primary Fennec project that ties them all together.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Method-Workflow is free software; Standard Perl license.

Method-Workflow is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
