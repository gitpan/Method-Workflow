package Method::Workflow::Result;
use strict;
use warnings;

use Exodist::Util qw/array_accessors/;

BEGIN {
    array_accessors qw/return tasks errors task_return/;
}

sub new {
    my $class = shift;
    my %proto = @_;
    bless( \%proto, $class );
}

1;

=head1 NAME

Method::Workflow::Result - Results of a workflow run

=head1 PUBLIC API METHODS

=over 4

=item @list = $result->return()

Get everything returned by the nested methods of the workflow.

=item @list = $result->task_return()

Get everything returned by the task methods.

=item @list = $result->errors()

Get all the errors.

=back

=head1 EXTENSIONS MAY NEED TO KNOW

=over 4

=item $result->push_return( $return )

Add a return.

=item $result->push_task_return( $return )

Add a task return.

=item $result->push_errors([ $workflow, $message ])

Add errors.

=item $result->push_tasks( @tasks )

Add tasks to be run (cleared at the end of the run.)

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
