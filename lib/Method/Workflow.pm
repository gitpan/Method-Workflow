package Method::Workflow;
use strict;
use warnings;

use Carp qw/croak/;
use Devel::Declare::Parser::Fennec;
use Exporter::Declare;
use Scalar::Util qw/blessed/;
use List::Util qw/shuffle/;
use Method::Workflow::Stack ':all';
use Try::Tiny;

use Exodist::Util qw/
    accessors
    array_accessors
    category_accessors
    blessed
    shuffle
    alias
    alias_to
/;

alias 'Method::Workflow::Task';

our $VERSION = '0.100';
our @CARP_NOT = qw/ Method::Workflow Method::Workflow::Util Method::Workflow:Task/;

#########
# Exports
export start_workflow {
    my $name = caller;
    croak "You must store the result of start_workflow()"
        unless defined wantarray;
    return __PACKAGE__->new( name => $name, method => sub {}, @_ )->begin;
}

keyword 'workflow';
#########

###########
# Functions
sub default_error_handler {
    for my $set ( @_ ) {
        my ( $trace, $msg ) = @$set;
        warn join( "\n  ", $msg, 'Workflow Stack:', map { blessed($_) . '(' . $_->name . ')' } @$trace ) . "\n";
    }
    die "There were errors (see above)";
}
###########

###############
# Class Methods
sub _import {
    my $class = shift;
    my ( $caller, $specs ) = @_;
    Task->export_to( $caller, $specs );
    1;
}

sub new {
    my $class = shift;
    my %proto = @_;

    $proto{$_} || croak "You must provide a $_"
        for $class->required;

    my $self = bless(
        {
            error_handler => \&default_error_handler,
            %proto,
        },
        $class,
    )->init(%proto);

    $self->parent_trace if $self->debug();
    return $self;
}
###############

###########
# Accessors
accessors qw/
    debug
    name
    method
    _acting_parent
    error_handler
    random
    sorted
    ordered
    parallel
    _prunner
/;

array_accessors qw/
    errors
    results
    tasks
/;

category_accessors qw/
    children
    _pre_run
    _post_run
/;
###########

##############################
# Object methods (overridable)
sub init     { shift            }
sub required { qw/ method name /}
sub pre_run  {                  }
sub post_run {                  }

sub run {
    my $self = shift;
    my ( $invocant ) = @_;
    $self->push_results( $self->do( $self->method, $invocant ));
}
##############################

######################
# Object methods (API)
sub observe   { ++(shift->{_observed}) }
sub observed  { shift->{_observed}     }
sub begin     { shift->stack_push      }
sub end       { shift->stack_pop       }
sub add_items { goto &add_item         }

sub has_ordering {
    my $self = shift;
    return 'random'  if $self->random;
    return 'sorted'  if $self->sorted;
    return 'ordered' if $self->ordered;
    return;
}

sub add_item {
    my $self = shift;
    $self->_add_item( $_ ) for @_;
}

sub do {
    my $self = shift;
    my ( $code, $invocant ) = @_;
    my @out;
    $self->stack_push;
    try   { push @out => $code->( $invocant || undef, $self ) }
    catch { $self->push_errors([ stack_trace(), $_ ])};
    $self->stack_pop;
    return @out;
}

sub run_workflow {
    my $self = shift;
    my ( $invocant, @want ) = @_;
    @want = ( 'task_results' )
        unless @want;

    $self->_acting_parent( 1 );

    my %out = $self->_run_workflow( $invocant );
    $self->error_handler->( @{$out{errors}})
        if $out{errors} && @{$out{errors}};

    my %taskout = $self->_run_tasks( $invocant, @{$out{tasks} });
    $self->error_handler->( @{$out{task_errors}})
        if $out{task_errors} && @{$out{task_errors}};

    $self->_acting_parent( 0 );

    # return results
    return unless defined wantarray;

    $out{"task_$_"} = $taskout{$_} for qw/tasks errors results/;
    my @ret = map { $out{$_} } @want;

    return wantarray ? @ret : $ret[0];
}
######################

########################
# Private Object Methods
sub _add_item {
    my $self = shift;
    my ( $item ) = @_;
    return unless $item;

    my $type = blessed( $item );

    croak "$item is not a task or workflow"
        unless $type && $type->isa( __PACKAGE__ );

    if( $type->isa( Task )) {
        $item->config( $self );
        $self->push_tasks( $item );
        return;
    }

    $self->push_children( $item );
    my $pre = $self->_pre_run_ref;
    my $post = $self->_post_run_ref;

     $pre->{ $type } ||= [ $item->pre_run  ];
    $post->{ $type } ||= [ $item->post_run ];
}

sub _run_tasks {
    my $self = shift;
    my ( $invocant, @tasks ) = @_;

    @tasks = sort { $a->name cmp $b->name } @tasks if $self->sorted;
    @tasks = shuffle @tasks if $self->random;

    unless( $self->parallel ) {
        my %taskout = ( errors => [], results => [], tasks => [], );
        $_->_run_workflow( $invocant, \%taskout ) for @tasks;

        return %taskout
    }

    my @errors;

    eval 'require Parallel::Runner; 1;'
        || die "Parallel::Runner is required for running tasks in parallel. $@";

    $self->_prunner( Parallel::Runner->new(
        $self->parallel,
        reap_callback => sub {
            my ( $status, $pid ) = @_;
            push @errors => [ stack_trace(), "$pid had exit status $status" ]
                if $status;
        },
    ));

    $self->_prunner->run( sub {
        my %out = $_->_run_workflow( $invocant );
        $self->error_handler->( @{$out{errors}})
            if @{$out{errors}};
    }) for @tasks;

    $self->_prunner->finish;
    $self->_prunner( undef );

    return( errors => \@errors );
}

sub _run_workflow {
    my $self = shift;
    my ($invocant, $out) = @_;
    $out ||= { errors => [], results => [], tasks => [], };

    $self->observe;

    $self->run( $invocant );
    push @{ $out->{errors}}  => $self->pull_errors;
    push @{ $out->{results}} => $self->pull_results;
    push @{ $out->{tasks}}   => ($self->tasks && $self->has_ordering)
        ? Task->new(
            name => $self->name,
            method => sub {},
            subtasks_ref => [ $self->pull_tasks ],
            $self->has_ordering => 1,
        ) : $self->pull_tasks;

    $self->stack_push;

    try {
        $_->( parent => $self, invocant => $invocant, %$out )
            for $self->pull_all__pre_run;

        $_->_run_workflow( $invocant, $out )
            for $self->pull_all_children;

        $_->( parent => $self, invocant => $invocant, %$out )
            for $self->pull_all__post_run;
    }
    catch {
        push @{ $out->{errors}} => [ stack_trace(), $_ ];
    };

    $self->stack_pop;

    return unless wantarray;
    return %$out;
}

sub DESTROY {
    my $self = shift;

    $self->stack_pop
        if stack_peek && stack_peek == $self;

    warn "Workflow '" . $self->name . "' was never observed"
        if $self->debug && !$self->observed
}
########################

1;

__END__

=head1 NAME

Method::Workflow - An OO general purpose declarative workflow framework

=head1 DESCRIPTION

This module provides an Object Oriented workflow framework. By default this
framework uses keywords for a declarative interface. Most elements of the
workflow are defined as methods, and will ultimately be run on a specified
object.

This Framowerk is intended to be used through higher level tools such as
L<Fennec>. As such the API leans twords providing more choices and
capabilities. In most use cases an API wrapper that hides most of the
descisions should be implemented.

=head1 SYNOPSYS

This synopsys makes no attempt to convey a use case. This is simply an example
of how to use the API. You define nestable workflows which should define
scenarios and data. You also define tasks which make use of that data.

    use strict;
    use warnings;
    use Method::Workflow;

    my @color;

    my $wf = start_workflow;

    workflow rainbow {
        $self->do_thing; # $self is automatically given to you, it will be the
                         # $invocant object listed below

        workflow red {
            $self->do_thing_again; #$self is free again.

            task red { push @color => 'red' }
        }
        workflow yellow {
            ...
            task yellow { push @color => 'yellow' }
        }
        workflow green {
            ...
            task green { push @color => 'green' }
        }
        workflow blue {
            ...
            task blue { push @color => 'blue' }
        }
    }

    # Define on object that the methods will be run on.
    my $invocant = SomeClass->new() || undef;

    # What return data do we care about?
    my @want = qw/ results task_results /;

    # Do it.
    my ( $results, $task_results ) = $wf->run_workflow( $invocant, @want );

=head1 WORKFLOWS AND TASKS

Workflows will run to depth in the order they are defined. Tasks are run
I<after> all workflows complete. This leads to the potential for powerful
advanced workflows. It also leads to potential spooky action.

    workflow root {
        my $thing;

        workflow a {
            $thing = 'a';
            task { print "$thing\n" }
        }
        workflow b {
            $thing = 'b';
            task { print "$thing\n" }
        }
    }

This example will print b twice, that is because all workflows run first,
meaning the value of $thing is set to 'b' before the tasks run. This is not a
bug, but rather a desired feature. See L<Method::Workflow::SPEC> and
L<Method::Workflow::Case> for expamples.

=head1 UNDER THE HOOD

L<Method::Workflow::Util> exports several methods for manipulating 'the stack'.
This is not the perl stack, but rather a stack of workflows. The stack is an
array of workflows.

When you use the declaritive keywords such as 'workflow NAME { ... }' a new
workflow is created, this workflow is added as a child to the topmost workflow
on the stack. When a workflow is run, it is pushed anto the stack as the
topmost item, thus any methods declared within are added to the proper parent.

When you call run_workflow() on a workflow it will run the workflows method,
then recurse into nested workflows. Once workflows have been run to depth the
tasks and errors are propogated down to the initial run_workflow() call. At
this point errors are handled, and tasks are run.

=head1 API

To create a workflow without magic:

    my $workflow = Methad::Workflow->new( name => $name, method => sub {
        # When magic is used $invocant is actually shifted off as $self.
        # $workflow is this workflow.
        my ( $invocant, $workflow ) = @_;
        ...
    });

The invocant is reffered to as $self for the sake of higher level libraries
which will hide the workflow details from their users.

=head2 EXPORTS

=over 4

=item $root_wf = start_workflow()

Starts a workflow and pushes it on to the stack. It is important to store the
workflow as it will be shifted off of the stack when the reference count hits
zero. It is also important to either remove all references, or call
$root_wf->end when you are done defining the workflow.

=item workflow NAME { ... }

Define an element of a workflow

=item task NAME { ... }

Define a task for the current workflow

=back

=head2 ORDERING TASKS

There are 3 sorting options, 'ordered' (default), 'sorted', and 'random'. They
can be specified when defining a workflow, or when calling start_workflow. here
is an example from the tests:

    my @order;
    $wf = start_workflow( sorted => 1 );
    workflow root {
        task c { push @order => 'c' }
        task a { push @order => 'a' }
        task b { push @order => 'b' }
        task 'y' { push @order => 'y' }
        task z { push @order => 'z' }
        workflow x ( ordered => 1 ) {
            task f { push @order => 'f' }
            task e { push @order => 'e' }
            task d { push @order => 'd' }
        }
    }
    $wf->run_workflow();

    is_deeply(
        \@order,
        [ qw/ a b c f e d y z /],
        "Nested re-ordering"
    );

=head2 ABSTRACT METHODS

These are convenience methods that allow you to hook into the workflow process.

=over 4

=item $obj = $obj->init( %args )

Called by the constructor giving you the opportunity to change or even replace
the created object at construction time.

=item @list = $class->required()

Should return a list of attributes that are required at construction.

=item @list = $obj->pre_run()

Should return a list of coderefs that should be called after this workflows
method is run, but before any nested workflows are run.

=item @list = $obj->post_run()

Should return a list of coderefs that should be called after nested workflows
are run.

=item $obj->run()

Should run this workflows method, and store results and errors. Here is the
default example.

    sub run {
        my $self = shift;
        my ( $invocant ) = @_;
        $self->push_results( $self->do( $self->method, $invocant ));
    }

=back

=head2 SIMPLE ACCESSORS

=over 4

=item $wf->parallel( $max )

=item $max = $wf->parallel()

Get/Set the max number of parallel processes to use when running tasks in
parallel, 0 means do not run tasks in parallel.

=item $wf->method( \&code )

=item $code = $wf->method()

Get/Set the method referenced by the workflow.

=item $wf->name( $name )

=item $name = $wf->name()

Get/Set the workflow name.

=item $wf->debug( $bool )

=item $bool = $wf->debug()

Turn debuging on/off.

=item $ordering_type = $wf->has_ordering()

Return the stringified name of the ordering method, undef if none is specified.

=item $bool = $wf->ordered()

=item $wf->ordered( $bool )

True if tasks are to be run in the order in which they were defined.

=item $bool = $wf->random()

=item $wf->random( $bool )

True if tasks are to be run in random order.

=item $bool = $wf->sorted()

=item $wf->sorted( $bool )

True if tasks should be sorted

=back

=head2 ACTION METHODS

=over 4

=item $wf->observe()

Mark the workflow as observed (happens when run)

=item $bool = $wf->observed()

Check if the workflow has been observed

=item $wf->add_item( @items )

=item $wf->add_items( @items )

Add tasks/workflows to this one. (called when keywords are used)

=item $wf->begin()

Set this workflow as the current on the stack.

=item $wf->end()

Pop this workflow off the stack (errors if this workflow is not the top)

=item @return = $wf->do( $code, $invocant )

Run $code as a method on $invocant. The return is what $code returns.

=item @results = $wf->run_workflow( $invocant, @want )

Run the workflow. @results is an array of arrays, each inner array is the list
of returns for an element of @want. Possible @want values are: results, errors,
tasks, task_results, task_errors, task_tasks.

=back

=head2 MANIPULATING RESULTS

These methods manipulate the results array which stores the return value from
the method with which the workflow was created. The run() method is responsible
for populating this.

=over 4

=item @items = $wf->results()

Get the results

=item @items = $wf->pull_results()

Get the results while also deleting them from the workflow.

=item $items = $wf->results_ref()

Get/Set the arrayref storing the results.

=item $wf->push_results( @items )

Add results

=back

=head2 MANIPULATING TASKS

=over 4

=item @items = $wf->tasks()

Get the tasks

=item @items = $wf->pull_tasks()

Get the tasks while also deleting them from the workflow.

=item $items = $wf->tasks_ref()

Get/Set the arrayref storing the tasks.

=item $wf->push_tasks( @items )

Add tasks

=back

=head2 MANIPULATING ERRORS

=over 4

=item @items = $wf->errors()

Get the errors

=item @items = $wf->pull_errors()

Get the errors while also deleting them from the workflow.

=item $items = $wf->errors_ref()

Get/Set the arrayref storing the errors

=item $wf->push_errors( @items )

Add errors

=back

=head2 MANIPULATING NESTED WORKFLOWS

=over 4

=item @items = $wf->children()

Get a list of all nested workflows (not to depth)

=item @items = $wf->pull_all_children()

Get all the nested workflows while also deleting them from the workflow.

=item @items = $wf->pull_children( $type )

Get all the nested workflows of a specific type while also deleting them from
the workflow.

=item $items = $wf->children_ref()

Get/Set the hashref storing the nested workflows.

=item $wf->push_children( @items )

Add a nested workflow

=item my @types = $wf->keys_children()

Get a list of all the types of nested workflows (What they are blessed as)

=back

=head2 CUSTOM ERROR HANDLERS

=over 4

=item $wf->error_handler( \&custom_handler )

=item $handler = $wf->error_handler()

Get/Set the error handler.

=back

The error handler should be a coderef. All errors will be passed in as
aguments. Each error is an array, the first element is a workflow stack trace,
the second is the error message itself. The stack trace is an array of workflow
objects.

Here is the default handler as an example:

    sub default_error_handler {
        for my $set ( @_ ) {
            my ( $trace, $msg ) = @$set;
            warn join(
                "\n  ",
                $msg,
                'Workflow Stack:',
                map { blessed($_) . '(' . $_->name . ')' } @$trace
            ) . "\n";
        }
        die "There were errors (see above)";
    }

=head1 EXTENDING

To extend Method::Workflow you should subclass Method::Workflow, possibly
subclass L<Method::Workflow::Task>, and familiarize yourself with
L<Method::Workflow::Stack>. Also read the section 'UNDER THE HOOD'.

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
