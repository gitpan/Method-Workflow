package Method::Workflow::Stack;
use strict;
use warnings;

use Scalar::Util qw/ blessed /;
use Carp qw/croak/;
use Exporter::Declare;
use Method::Workflow::Meta;

our @EXPORT_OK = qw/
    stack_current
    stack_push
    stack_pop
    stack_parent
/;

our @CARP_NOT = qw/
    Method::Workflow
    Method::Workflow::Base
    Method::Workflow::Stack
    Exporter::Declare
/;

our @STACK;

sub stack_current { $STACK[-1]        }
sub stack_push    { push @STACK => @_ }
sub stack_parent  { $STACK[-2]        }

sub stack_pop {
    my ( $desired ) = @_;

    croak "You must specify the item that should be popped."
        unless $desired;

    my $got = pop @STACK;

    croak "Nothing to pop."
        unless $got;

    croak "Item popped does not match desired item."
        unless "$got" eq "$desired";

    return 1;
}

1;

=head1 NAME

Method::Workflow::Stack - Stack manager for Method::Workflow.

=head1 DESCRIPTION

This is the stack manager for L<Method::Workflow>. Use the exported functions
for more advanced workflow implementations.

=head1 EXPORTED FUNCTIONS

=head2 DEFAULT

B<Nothing is exported by default>

=head2 ON REQUEST

=over 4

=item $item = stack_current()

Returns the top item on the stack

=item stack_parent()

Returns the item just below the top.

=item stack_push( $item )

Push an item on to the stack, all workflow elements generated via keyword will
be added to this item until it is popped or something else is pushed.

=item stack_pop( $item )

Remove the top-most item from the stack, you must provide the item you expect to
be popped for consistancy checking.

=back

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
