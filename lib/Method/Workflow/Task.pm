package Method::Workflow::Task;
use strict;
use warnings;
use Exodist::Util qw/array_accessors shuffle/;
use Method::Workflow::Stack qw/keyword/;

use base 'Method::Workflow';

keyword 'task';

array_accessors qw/subtasks/;

sub config {}

sub run {
    my $self = shift;
    my ( $invocant ) = @_;

    $self->push_results( $self->do( $self->method, $invocant ));

    $self->push_subtasks( $self->pull_tasks )
        if $self->tasks;

    return unless my @tasks = $self->subtasks;

    @tasks = sort { $a->name cmp $b->name } @tasks if $self->sorted;
    @tasks = shuffle @tasks if $self->random;

    my %taskout = ( errors => [], results => [], tasks => [], );
    $_->_run_workflow( $invocant, \%taskout ) for @tasks;

    $self->push_results( @{$taskout{results}});
    $self->push_errors( @{$taskout{errors}});
    $self->add_item( @{$taskout{tasks}});

    return;
}

1;

__END__

=head1 NAME

Method::Workflow::Task - Basic task objects

=head1 DESCRIPTION

Tasks are nested workflows that run at the ond of the workflow process.

=head1 FENNEC PROJECT

This module is part of the Fennec project. See L<Fennec> for more details.
Fennec is a project to develop an extendable and powerful testing framework.
Together the tools that make up the Fennec framework provide a potent testing
environment.

The tools provided by Fennec are also useful on their own. Sometimes a tool
created for Fennec is useful outside the greator framework. Such tools are
turned into their own projects. This is one such project.

=over 2

=item L<Fennec> - The core framework

The primary Fennec project that ties them all together.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Method-Workflow is free software; Standard perl licence.

Method-Workflow is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
