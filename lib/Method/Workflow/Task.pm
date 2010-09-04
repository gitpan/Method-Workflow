package Method::Workflow::Task;
use strict;
use warnings;

use Method::Workflow::Stack qw/ stack_current /;
use Method::Workflow::Meta qw/ meta_for /;
use Method::Workflow qw/ accessors handle_error /;
use Scalar::Util qw/ blessed /;
use List::Util qw/ shuffle /;
use Try::Tiny;
use Exporter::Declare;

my @ARRAY_ACCESSORS = qw/ before_each after_each before_all after_all subtasks /;

our @ORDER = qw/ ordered sorted random /;
accessors qw/ workflow owner _ordering task /, map { "${_}_ref" } @ARRAY_ACCESSORS;

sub order_options { @ORDER }

for my $accessor ( @ARRAY_ACCESSORS ) {
    my $ref = "${accessor}_ref";
    my $sub = sub {
        my $self = shift;
        my $list = $self->$ref;
        unless ( $list ) {
            $list = [];
            $self->$ref($list);
        }
        push @$list => @_;
        return @$list;
    };
    no strict 'refs';
    *$accessor = $sub;
}

export task fennec {
    my ( $owner, $return_owner );
    if ( blessed( $_[0] )) {
        $owner = shift( @_ );
        $return_owner = 1;
    }
    else {
        $owner = stack_current();
        $return_owner = 0;
    }

    my $name = shift;
    my ( $method, %proto ) = Method::Workflow::_method_proto( @_ );
    my $root = $owner->root;

    my $task = __PACKAGE__->new(
        %proto,
        task => Method::Workflow::Base->new(
            %proto,
            name => $name,
            method => $method,
            parent => $root,
        ),
        owner => $root,
        workflow => $owner,
    );

    if ( $owner->isa( 'Method::Workflow::Base' )
    && (my ( $order, $orderant ) = $owner->ordering )) {
        my $meta = meta_for($orderant);
        if ( "$orderant" eq "$owner" && !$meta->prop('order_root_task') ) {
            my $root_task = __PACKAGE__->new(
                _ordering => $order,
                owner => $root,
                workflow => $owner,
            );

            $meta->prop( 'order_root_task', $root_task );
            meta_for($root)->add_task( $root_task );
        }
        meta_for($orderant)->prop('order_root_task')->add_subtasks( $task );
    }
    else {
        meta_for($root)->add_task( $task );
    }

    return $owner if $return_owner;
    return;
}

sub new {
    my $class = shift;
    my %proto = @_;
    return bless({
        subtasks_ref => [],
        %proto,
    }, $class );
}

sub name {
    my $self = shift;
    return $self->task->name
        if $self->task;

    return $self->workflow->name
        if $self->workflow;

    return 'un-named';
}

sub set_order_unless_set {
    my ( $self, $order ) = @_;
    return if $self->_ordering;
    $self->_ordering( $order );
    $_->set_order_unless_set( $order )
        for $self->subtasks;
}

sub add_subtasks {
    my $self = shift;
    push @{ $self->subtasks_ref } => @_;
    if ( $self->_ordering ) {
        $_->set_order_unless_set( $self->_ordering )
            for @_;
    }
}

sub ordering {
    my $self = shift;
    return $self->_ordering()
        if $self->_ordering();

    if ( $self->workflow && $self->workflow->isa( 'Method::Workflow::Base' )) {
        my $order = $self->workflow->ordering;
        return $order if $order;
    }

    return 'ordered';
}

sub run_task {
    my $self = shift;
    my $owner = $self->owner;
    my @out;

    my $runner = meta_for( $owner )->prop( 'task_runner' )
              || \&default_runner;

    try { @out = $self->$runner( $owner     )}
    catch { handle_error( $self, $owner, $_ )};

    return @out;
}

sub default_runner {
    my $self = shift;
    my @out;

    $self->run_before_alls;

    if ( $self->task ) {
        $self->run_before_each;
        push @out => $self->_run_task;
        $self->run_after_each;
    }

    push @out => $self->run_subtasks;
    $self->run_after_alls;

    return @out;
}

sub run_before_alls {
    my $self = shift;
    $_->run_workflow( $self->owner )
        for $self->before_all;
}

sub run_after_alls {
    my $self = shift;
    $_->run_workflow( $self->owner )
        for reverse $self->after_all;
}

sub run_before_each {
    my $self = shift;
    $_->run_workflow( $self->owner )
        for $self->before_each;
}

sub run_after_each {
    my $self = shift;
    $_->run_workflow( $self->owner )
        for reverse $self->after_each;
}

sub _run_task {
    my $self = shift;
    my @out;
    my $owner = $self->owner;
    $self->task->run_workflow( $self->owner );
}

sub run_subtasks {
    my $self = shift;

    my @list = $self->subtasks;

    @list = sort { $a->name cmp $b->name } @list
        if $self->ordering eq 'sorted';

    @list = shuffle @list if $self->ordering eq 'random';

    $_->run_task( $self->owner )
        for @list
}

1;

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
