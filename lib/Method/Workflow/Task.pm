package Method::Workflow::Task;
use strict;
use warnings;

use Method::Workflow::SubClass;
use Exodist::Util qw/array_accessors/;
use Try::Tiny;

array_accessors qw/subtasks/;

keyword 'task';

sub process_method {
    my $self = shift;
    my ( $invocant, $result ) = @_;

    try   { $result->push_task_return( $self->run_method( $invocant ))}
    catch { $result->push_errors( $_ )};

    $self->run_tasks( $invocant, $result, $self->pull_subtasks );
}

1;

__END__

=head1 NAME

Method::Workflow::Task - Basic task objects

=head1 DESCRIPTION

Tasks are nested workflows that run at the end of the workflow process.

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
