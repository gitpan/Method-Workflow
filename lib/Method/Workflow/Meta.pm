package Method::Workflow::Meta;
use strict;
use warnings;
use Exporter::Declare;
use Carp qw/croak/;
use Scalar::Util qw/ blessed /;

our @EXPORT_OK = qw/meta_for/;
our %METAS;

sub meta_for {
    my $for = shift || caller;
    $METAS{ $for } ||= Method::Workflow::Meta->_new();
    return $METAS{ $for };
}

sub new {
    my $class = shift;
    croak "You should never create a new $class yourself"
}

sub _new {
    my $class = shift;
    return bless( [{},{}], $class );
}

sub add_items { goto &add_item }
sub add_item {
    my $self = shift;
    $self->_add_item( $_ ) for @_;
}

sub _add_item {
    my $self = shift;
    my ( $item ) = @_;
    my $key = $self->_item_key( $item );
    push @{ $self->items_ref->{ $key }} => $item;
}

sub _item_key {
    my $self = shift;
    my ($item) = @_;
    return '!' unless ref $item;
    return blessed( $item ) || ref( $item );
}

sub pull_items {
    my $self = shift;
    my $key = $_[0] || '!';
    return @{ delete( $self->items_ref->{ $key }) || [] };
}

sub items {
    my $self = shift;
    return ( map { @$_ } values %{ $self->items_ref });
}

sub items_ref {
    my $self = shift;
    return $self->[0];
}

sub properties_ref { shift->[1] }

sub properties { %{ shift->[1] }}

sub prop { goto &property }

sub property {
    my $self = shift;
    my $name = shift;
    return unless $name;
    ( $self->properties_ref->{ $name }) = @_ if @_;
    return $self->properties_ref->{ $name };
}

1;

=head1 NAME

Method::Workflow::Meta - Meta class for Method::Workflow.

=head1 DESCRIPTION

The class that holds meta-data for items with workflows, and also for workflow
elements.

=head1 EXPORTED FUNCTIONS

=head2 DEFAULT

B<Nothing is exported by default>

=head2 ON REQUEST

=over 4

=item $meta = meta_for( $item );

Will return the meta class for the specified item (autovivifying)

=back

=head1 METHODS

=over 4

=item $meta->add_item( $item )

Add an item to the meta data.

=item @list = $meta->items()

Get a list of all items in the meta data.

=item $list_ref = $meta->items_ref()

Get a reference to the items hash ( type => \@list ).

=item $value = $meta->property( $name )

=item $value = $meta->prop( $name )

Get the value of a named property.

=item $meta->prop( $name, $value )

=item $meta->property( $name, $value )

Set the value of a named property.

=item %props = $meta->properties()

=item $props_ref = $meta->properties_ref()

Get a ref to the properties hash.

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
