package Method::Workflow::Stack;
use strict;
use warnings;

use Exporter::Declare;
use Exodist::Util qw/inject_sub blessed weaken /;
use Carp qw/croak/;

our @EXPORT = qw/
    keyword
/;

our @EXPORT_OK = qw/
    stack_push
    stack_pop
    stack_peek
    stack_trace
/;

my @STACK;
sub stack_trace {
    my $idx = $#STACK;
    my @out;
    do {
        unshift @out => $STACK[$idx];
    } until $STACK[$idx--]->_acting_parent;
    return \@out;
}

sub stack_peek {
    return unless @STACK;
    # -1 makes it work as method or function
    my ($num) = $_[-1];
    $num = -1 unless defined $num && $num =~ m/^-?\d+$/;
    return $STACK[$num];
}

sub stack_push {
    my $workflow = shift;
    croak "Only instances of " . __PACKAGE__ . " and subclasses can be added to the stack."
        unless $workflow->isa( 'Method::Workflow' );
    push @STACK => $workflow;
    weaken( $STACK[-1] );
    return $workflow;
}

sub stack_pop {
    my $workflow = shift;
    my $current = stack_peek();

    croak "You must specify workflow to pop"
        unless $workflow;

    croak "No current workflow to pop"
        unless $current;

    croak(
        "Inconsistant stack, attempt to pop '"
        . $workflow->name
        . "', but '"
        . $current->name
        . "' is the current top item."
    ) unless $workflow == $current;

    pop @STACK;
    return $workflow;
}

sub keyword {
    my ( $keyword ) = @_;
    my $caller = caller;

    inject_sub( $caller, 'keyword', sub { $keyword }, 1 );

    $caller->export(
        $keyword,
        'fennec',
        sub {
            my $name = shift;
            my ( $method, %proto ) = _method_proto( @_ );
            my $current = Method::Workflow::stack_peek();

            croak "No current workflow, did you forget to run start_workflow() or \$workflow->begin()?"
                unless $current;

            $current->add_item(
                $caller->new(
                    %proto,
                    name => $name || undef,
                    method => $method || undef,
                ),
            );
        }
    );
}

sub _method_proto {
    return ( $_[0] ) if @_ == 1;
    my %proto = @_;
    return ( $proto{ method }, %proto );
}

1;

__END__

=head1 NAME

Method::Workflow::Stack - Stack package for Method::Workflow

=head1 DESCRIPTION

This package provides tools for manipulating the workflow stack

=head1 EXPORTS

=head2 EXPORTED BY DEFAULT

=item keyword( $name )

Used by subclasses of L<Method::Workflow> to generate and export a declaritive
keyword.

=head2 EXPORTED UPON REQUEST

=item stack_push( $item )

Add a workflow to the stack.

=item stack_pop( $item )

Remove a workflow from the stack. You must specify what item you expct to be
popped for consistancy checking.

=item $item = stack_peek()

Get the topmost item on the stack.

=item $items_ref = stack_trace()

Get a trace. This will return every element in the stack from the top down to
the topmost parent workflow.

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
