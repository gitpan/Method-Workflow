package Method::Workflow::Base;
use strict;
use warnings;

use Try::Tiny;
use Hook::AfterRuntime;
use Exporter::Declare;
use Carp qw/croak/;
use Scalar::Util qw/ blessed /;
use Method::Workflow qw/accessors/;
use Method::Workflow::Meta qw/ meta_for /;

use Method::Workflow::Stack qw/
    stack_push stack_pop stack_current
/;

our @CARP_NOT = ( 'Method::Workflow', 'Exporter::Declare' );
our @EXPORT_OK = qw/ run_workflow debug /;
our $DEBUG = 0;

accessors qw/ _observed method name parent _parent_trace /;

# Overridable
sub init          { shift                   }
sub required      { qw/ method name parent /}
sub pre_run_hook  {                         }
sub post_run_hook {                         }
sub import_hook   {                         }

sub run {
    my ( $self, $root ) = @_;
    $self->method->( $root, $self );
}

# Not Overridable

sub handle_error {
    my ( $owner, $root, @errors ) = @_;

    my $handler = meta_for( $owner )->prop( 'error_handler' )
               || meta_for( $root )->prop( 'error_handler' )
               || sub { stack_pop( $owner ); die join( ' ', @errors )};

    $handler->( $owner, $root, @errors );
}

sub debug {
    ($DEBUG) = @_ if @_;
    $DEBUG;
}

sub observe { shift->_observed(1) }

gen_export_ok start_class_workflow {
    my ( $exporter, $importer ) = @_;
    sub { stack_push( $importer )}
}

gen_export_ok end_class_workflow {
    my ( $exporter, $importer ) = @_;
    sub { stack_pop( $importer )}
}

sub _import {
    my $class = shift;
    my ( $caller, $spec ) = @_;

    $class->import_hook( $caller, $spec );

    __PACKAGE__->export_to( $caller, undef, 'run_workflow' )
        unless $caller->can( 'run_workflow' );

    unless ( $spec && $spec->{ 'classlevel' }) {
        __PACKAGE__->export_to(
            $caller,
            undef,
            qw/ start_class_workflow end_class_workflow /
        ) unless $caller->can( 'start_class_workflow' );

        return;
    }

    my $current = stack_current();
    return if $current && "$current" eq "$caller";

    stack_push( $caller );
    after_runtime { stack_pop( $caller ) };
}

sub new {
    my $class = shift;
    my %proto = @_;

    $proto{$_} || croak "You must provide a $_"
        for $class->required;

    my $self = bless( \%proto, $class )->init(%proto);
    $self->parent_trace if debug();
    return $self;
}

sub run_workflow {
    my ( $owner, $root ) = @_;
    $owner ||= caller;
    $root ||= $owner;
    my $meta = meta_for( $owner );
    my @out;

    stack_push( $owner );

    # Run our method
    if ( blessed( $owner ) && $owner->isa( __PACKAGE__ )) {
        $owner->observe();
        try   { push @out => $owner->run( $root )}
        catch { handle_error( $owner, $root, $_ )}
    }

    # Recurse into children

    for my $hook ( $meta->pre_run_hooks ) {
        try { $hook->(
            owner => $owner,
            meta  => $meta,
            root  => $root,
        )} catch { handle_error( $owner, $root, $_ )}
    }

    for my $item ( $meta->items ) {
        try   { push @out => $item->run_workflow( $root )}
        catch { handle_error( $owner, $root, $_ )        }
    }

    for my $hook ( $meta->post_run_hooks ) {
        try { $hook->(
            owner => $owner,
            meta  => $meta,
            root  => $root,
            out   => \@out,
        )} catch { handle_error( $owner, $root, $_ )}
    }

    stack_pop( $owner );
    return @out;
}

sub parent_trace {
    my $self = shift;
    my $parent = $self->parent;
    unless ( $self->_parent_trace ) {
        $self->_parent_trace(
            "  " . $self->display . "\n"
                 . ( $parent
                    ? ( $parent->can('display') ? $parent->parent_trace : "  $parent" )
                    : "" )
        );
    }
    $self->_parent_trace;
}

sub root {
    my $self = shift;
    my $parent = $self->parent;
    return $parent->isa( __PACKAGE__ )
        ? $parent->root
        : $parent;
}

sub display {
    my $self = shift;
    return blessed( $self ) . " - '" . $self->name . "'";
}

sub DESTROY {
    my $self = shift;
    return if $self->_observed || !debug();

    warn $self->display . " was never observed.\n"
        . <<EOT . $self->parent_trace . "\n\n";
This usually means you never called run_workflow() on a class or object that
defined a workflow
Trace:
EOT
}

1;

=head1 NAME

Method::Workflow::Base - Base class for workflow elements

=head1 DESCRIPTION

You must subclass this object when defining a new workflow element class.

=head1 OVERRIDABLE METHODS

=over 4

=item $self->init( %params )

Called by new() after construction as a hook for you to use.

=item @list = $self->required()

Returns a list of parameters that should be required for construction. By
default it returns 'method' and 'name'.

=item @results = $self->run( $root )

Default defenition:

    sub run {
        my ( $self, $root ) = @_;
        $self->method->( $root, $self );
    }

Should handle the work for this element and return its results. In most cases
this simply runs the codeblock provided to the keyword at construction. This
method is not responsible for child elements.

=back

=head2 HOOKS

Hooks give you the opportunity to manipulate the metadata before any workflow
elements of an item are run. They also let you run code after all elements have
run.

=over 4

=item $class->import_hook( $caller, $specs )

Override this if you need to do something on import. The first argument is the
original caller's class. The second argument is the specs hash that comes from
L<Exporter::Declare>. Any orguments from import that start with ':' will be
listed here (including import lists).

=item ($name => $coderef, ...) = $self->pre_run_hook( %existing )

Should return a list of name => coderefs that will be run before all children
when run_workflow() is called on an element that has children of your type.
Name is mandatory, you can check the params to ensure the hook is not already
installed.

Hook will be run with the following parameters:

    $hook->(
        owner => $owner,
        meta  => $meta,
        root  => $root,
    );

=item (name => $coderef, ...) = $self->post_run_hook( %existing )

Should return a list of name => coderefs that will be run after all children
when run_workflow() is called on an element that has children of your type.
Name is mandatory, you can check the params to ensure the hook is not already
installed.

Hook will be run with the following parameters:

    $hook->(
        owner => $owner,
        meta  => $meta,
        root  => $root,
        out   => \@out,
    );

The 'out' parameter contains a reference to the array of items that will be
returned by run_workflow, giving you a chance to add/remove items.

=back

=head1 AVAILABLE METHODS

=over 4

=item $self->new( %params )

Create a new instance.

=item $self->run_workflow( $owner, $root )

Run the workflow element and children.

Defaults:

    $owner ||= caller();
    $root ||= $owner;

=item $self->parent_trace()

Returns a stringified trace of the element and it's parents.

=item $self->display()

Returns the display string used te represent this item in a trace.

=item $self->observe()

Mark this instance as observed so that it does not generate a warning in debug
mode.

=item $self->DESTROY

In debug mode destruction will issue a warning when the item is destroyed
without having been observed. This is toggled to true when run_workflow() is
called.

=item error_handler( sub { my ( $owner, $root, @errors ) = @_; ... })

Define a handler to handle exceptions thrown by workflow elements.

=back

=head1 EXPORTS

=over 4

=item $KEYWORD

Whatever keyword you define with the 'keyword' keyword will be exported as a
construction shortcut to define elements of this type declaratively.

=item error_handler { my ( $owner, $root, @errors ) = @_; ... }

Define a handler to handle exceptions thrown by workflow elements.

=item run_workflow()

This will be exported whenever it is not already present in the importing
class.

=item start_class_workflow()

Used to start a class-level workflow.

=item end_class_workflow()

Used to end a class-level workflow.

=item debug( $bool )

Turns debug mode on and off (Can not be used as a method).

=back

=head1 NOTE ON IMPORT

Do not override import() or _import().

If you need to do something on import you should override import_hook().

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
