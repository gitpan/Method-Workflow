package Method::Workflow;
use strict;
use warnings;

our $VERSION = '0.203';

use Try::Tiny;
use Exporter::Declare qw/ -magic -all /;
use Method::Workflow::SubClass ':nobase';
use Devel::Declare::Parser::Fennec;
use Carp qw/croak/;

use Exodist::Util qw/
    accessors
    array_accessors
    category_accessors
    alias
    inject_sub
    first
    shuffle
    blessed
/;

alias qw/
    Method::Workflow::Task
    Method::Workflow::Result
    Method::Workflow::Method
/;

keyword 'workflow';

default_export new_workflow fennec {
    my $name = shift;
    my $method = pop( @_ ) if @_ == 1;
    my $caller = caller;

    __PACKAGE__->new(
        name => $name,
        method => $method || undef,
        invocant_class => $caller,
        @_,
    );
}

default_export do_workflow fennec {
    my $name = shift;
    my $method = pop( @_ ) if @_ == 1;
    my $caller = caller;

    __PACKAGE__->new(
        name => $name,
        method => $method || undef,
        invocant_class => $caller,
        @_,
    )->run;
}

default_export run_workflow { caller()->root_workflow->run( @_ ) }

default_export import_templates {
    my $caller = caller;
    parent_workflow( $caller )->push_templates( @_ )
}

accessors qw/
    is_root
    invocant_class
    error_handler
    parallel
    random
    sorted
    ordered
    name
    method
    parent_ordering
/;

array_accessors qw/
    tasks
    templates
/;

category_accessors qw/
    children
/;

sub init {}

sub after_import {
    my $class = shift;
    my ( $caller, $specs ) = @_;
    Task->export_to( $caller );

    unless ( $caller->can( 'root_workflow' )) {
        my $root = __PACKAGE__->new(
            name => $caller,
            invocant_class => $caller,
            $specs->config->{ random  } ? ( random => 1  ) : (),
            $specs->config->{ sorted  } ? ( sorted => 1  ) : (),
            $specs->config->{ ordered } ? ( ordered => 1 ) : (),
        );
        inject_sub( $caller, 'root_workflow', sub { $root });
    }
}

sub new {
    my $class = shift;
    my %proto = @_;
    my $self = bless( \%proto, $class );
    $self->init;
    return $self;
}

sub ordering {
    my $self = shift;
    return first { $self->$_ } qw/random sorted ordered/;
}

sub run {
    my $self = shift;
    my $invocant = $self->get_invocant( @_ );
    my $result = Result->new();

    local $self->{is_root} = 1;

    $self->process( $invocant, $result );
    $self->run_tasks( $invocant, $result, $result->pull_tasks )
        while $result->tasks;

    $self->handle_errors( $result );

    return $result;
}

sub run_tasks {
    my $self = shift;
    my ( $invocant, $result, @tasks ) = @_;
    return unless @tasks;

    my $random = $self->random;
    my $sort = $random ? 0 : $self->sorted;
    my $ordered = ($random || $sort) ? 0 : $self->ordered;

    if ( $self->parent_ordering && !( $random || $sort || $ordered )) {
        my $order = $self->parent_ordering;
        $random = 1 if $order eq 'random';
        $sort = 1 if $order eq 'sorted';
    }

    @tasks = sort { $a->name cmp $b->name } @tasks
        if $sort;
    @tasks = shuffle @tasks if $random;

    my $runner = $self->parallel ? 'run_items_parallel' : 'run_items';

    $self->$runner( $invocant, $result, @tasks )
}

sub process_method {
    my $self = shift;
    my ( $invocant, $result ) = @_;

    try   { $result->push_return( $self->run_method( $invocant ))}
    catch { $result->push_errors( [ $self, $_                  ])};
}

sub process {
    my $self = shift;
    my ( $invocant, $result ) = @_;

    $self->process_method( $invocant, $result );
    $self->import_templates( $invocant, $result );

    if( my @tasks = $self->pull_tasks ) {
        $result->push_tasks(
            $self->ordering && !$self->is_root
                ? Task->new( name => $self->name, subtasks_ref => \@tasks, $self->ordering => 1 )
                : @tasks
        );
    }

    $self->pre_child_run_hook( $invocant, $result );
    $self->run_items( $invocant, $result, $self->pull_all_children );
    $self->post_child_run_hook( $invocant, $result );

    return $result;
}

sub pre_child_run_hook  {}
sub post_child_run_hook {}

sub run_items {
    my $self = shift;
    my ( $invocant, $result, @items ) = @_;
    return unless @items && $items[0];

    $_->process( $invocant, $result ) for @items;
}

sub run_items_parallel {
    my $self = shift;
    my ( $invocant, $result, @items ) = @_;

    eval 'require Parallel::Runner; 1;'
        || die "Parallel::Runner is required for running tasks in parallel. $@";

    my %proc_map;

    my $runner = Parallel::Runner->new(
        $self->parallel,
        reap_callback => sub {
            my ( $status, $pid  ) = @_;
            my $wf = $proc_map{$pid};
            $result->push_errors([ $wf || undef, "$pid had exit status $status" ])
                if $status;
        },
    );

    for my $item ( @items ) {
        my $proc = $runner->run(sub { $_->process( $invocant, $result )});
        $proc_map{$proc->pid} = $item;
    }

    $runner->finish;
}

sub run_method {
    my $self = shift;
    my ( $invocant, $method ) = @_;
    $method ||= $self->method;
    return unless $method;

    return Method->new(
        sub => sub { $method->( @_ )},
        workflow => $self,
    )->( $invocant, $self );
}

sub get_invocant {
    my $self = shift;
    return $_[0] if @_ == 1 && blessed( $_[0] );

    return $self->invocant_class->new( @_ )
        if $self->invocant_class->can( 'new' );

    return bless( {@_}, $self->invocant_class );
}

sub add_item {
    my $self = shift;
    my ($item) = @_;
    croak "Cannot add item to non-object '$self'"
        unless blessed( $self );

    return $self->push_tasks( $item )
        if $item->isa( Task() );

    $self->push_children( $item );
    $item->parent_ordering( $self->ordering || $self->parent_ordering );
}

sub import_templates {
    my $self = shift;
    my ( $invocant, $result ) = @_;
    for my $template ( $self->templates ) {
        if ( blessed( $template )) {
            try   { $self->run_method( $invocant, $template->method || sub {()})}
            catch { $result->push_errors([ $template, $_                      ])};
        }
        else {
            eval "require $template; 1" || die $@;
            $self->push_children( $template->root_workflow->children );
            $self->push_tasks( $template->root_workflow->tasks );
        }
    }
}

sub handle_errors {
    my $self = shift;
    my ($result) = @_;
    return unless $result->errors;

    my $handler = $self->error_handler;
    return $handler->( $result->errors )
        if $handler;

    warn $_ for $result->errors;
    die "There were errors (See above)";
}

1;

__END__

=head1 NAME

Method::Workflow - Dynamic/Nested Workflows that can act as methods on an object.

=head1 DESCRIPTION

In this module a workflow is a sequence of methods, possibly nested,
associated with an object or class, that can be programmatically
generated, chained or mixed.

Generally you declare workflow methods as small parts of a greater
design. A good example of what this module attempts to achieve is Ruby's
RSPEC L<http://rspec.info>. However workflows need not be restricted to
testing.

Example workflow (Method::Workflow::Case):

Each 'task' method will be run for each 'case' method

    cases example {
        my $target;
        case a { $target = "case 1" }
        case b { $target = "case 2" }
        case c { $target = "case 2" }

        action display { print "$target\n" }
        action display_cap { print uc($target) . "\n" }
    }

    run_workflow();

Prints:

    case 1
    CASE 1
    case 2
    CASE 2
    case 3
    CASE 3

=head1 SYNOPSIS

=head2 PACKAGE WORKFLOW

    package MyWorkflow;
    use strict;
    use warnings;

    use Method::Workflow;

    workflow my_workflow {
        # $self is available for free
        $self->do_thing;

        ...

        # Tasks are all run after the workflow is complete, but before it
        # returns.
        task do_later { ... }
    }

    workflow another_workflow {
        ...
        task do_later { ... }
    }

    # Creates an instance of MyWorkflow using new() if it is defined
    # Each method in the workflow is run with the instance as $self.
    # Result is a L<Method::Workflow::Result> object.

    my $result = run_workflow( $invocant || %constructor_args );

    1;

=head2 INDEPENDENT WORKFLOW

    package MyWorkflow;
    use strict;
    use warnings;

    use Method::Workflow;

    my $wf = new_workflow root {
        workflow my_workflow {
            $self->do_thing;
            ...
            task do_later { ... }
        }

        workflow another_workflow {
            ...
            task do_later { ... }
        }
    }

    my $result = $wf->run( $invocant || %constructor_args );

    1;

Or in one shot:

    package MyWorkflow;
    use strict;
    use warnings;

    use Method::Workflow;

    my $result = do_workflow root {
        workflow my_workflow {
            $self->do_thing;
            ...
            task do_later { ... }
        }

        workflow another_workflow {
            ...
            task do_later { ... }
        }
    }

    1;

=head1 API

=head2 DECLARATIVE API (EXPORTS)

=over 4

=item workflow NAME { ... }

Add a child workflow to the current workflow or class.

=item task NAME { ... }

Add a task to the current workflow or class.

=item my $wf = new_workflow NAME { ... }

Create a new an independent workflow.

=item my $result = do_workflow NAME { ... }

Create and run an independent workflow.

The result will be an instance of L<Method::Workflow::Result>.

=item my $result = run_workflow( $invocant || %construction_args )

Run the class root workflow. %construction_args will be passed to the
constructor for the invocant class to create the invocant object. If a blessed
object is the only argument than that object will be used as the invocant.

The result will be an instance of L<Method::Workflow::Result>.

=item import_templates( @CLASSES, @WORKFLOW_OBJS )

Add the specified classes and workflow objects to the list of templates in the
current workflow.

=item $wf = root_workflow()

=item $wf = $class->root_workflow()

Get the root workflow for the current class. Can also be used as a class
method.

=back

=head2 OO API

This covers only the methods that are useful in general. Methods that are not
private, but not useful to most people will be covered in the section titled
INTERNAL API

=head3 SIMPLE ACCESSORS

These are all simple get/set accessors. They all take a single value, and
return the value.

=over 4

=item $value = $wf->invocant_class( $value )

An instance of the invocant class will be constructed and provided as the first
argument ($self) to the workflow mothods.

=item $value = $wf->error_handler( sub { ... })

Used to define a custom error handler.

=item $value = $wf->parallel( $value )

If set to an integer tasks will be run in that number of child processes.

B<NOTE> Parallel tasks is still experimental and untested.

=item $value = $wf->random( $value )

Tasks will be run in random order if true.

=item $value = $wf->sorted( $value )

Tasks will be sorted by name and then run if set to true.

=item $value = $wf->ordered( $value )

Tasks will be run in the order they were defined (default) if this is true.

=item $value = $wf->name( $value )

Get/Set the name of the task.

=item $value = $wf->method( $value )

Get/Set the coderef that is associated with this workflow.

=back

=head3 METHODS

=over 4

=item $wf = $class->new(name => $name, invocant_class => __PACKAGE__, method => sub { ... })

Create a new instance of Method::Workflow.

=item $wf->init()

Called by new just before it returns. Useful for subclasses, currently does
nothing.

=item $ordering = $wf->ordering()

Returns the name of the ordering that will be used, 'random', 'sorted',
'ordered', or undef if none is set.

=item $result = $wf->run( $invocant || %constructor_args )

Runs the workflow against a new instance of invocant_class created using
%constructor_args. If a blessed object is the only argument, it will be used
as the invocant.

The result will be an instance of L<Method::Workflow::Result>.

=item $wf->add_item( $workflow || $task )

Add a child workflow or task to the workflow. This is primarily used by the
keywords.

=item @list = $wf->templates()

Get a list of all the workflows this class inherits from.

=item $wf->push_templates( @classes, @warkflows )

Use the specified workflows or classes that have root workflows as templates.
This means $wf will inherit children and tasks form the templates.

=back

=head2 INTERNAL API

=over 4

=item $list_ref = $wf->templates_ref( $newref )

Get/Set the arrayref that holds the list of template workflows.

=item @list = $wf->pull_templates()

Get the list of templates while also clearing the list.

=item $wf->import_templates()

Does the action of inheriting child workflows and tasks from the templates.
Should be called once per run.

=item @list = $wf->tasks()

=item $list_ref = $wf->tasks_ref( $newref )

=item @list = $wf->pull_tasks()

=item $task = $wf->pop_tasks()

=item $task = $wf->shift_tasks()

=item $wf->push_tasks( @tasks )

=item $wf->unshift_tasks( @tasks )

These are methods for manipulating the list of tasks. The list is cleared at
the end of a run. In general you should not use these directly. Use add_item()
to add tasks to a workflow.

=item @list = $wf->children()

=item @classes = $wf->children_keys()

=item $wf->push_children( @workflows )

=item @list = $wf->pull_children( $class )

=item @list = $wf->pull_all_children()

These are methods for manipulating the list of children. The list is cleared at
the end of a run. In general you should not use these directly. Use add_item()
to add children to a workflow.

Some plugins may wish to make use of these to remove children of their specific
class and replace them with tasks.

=item $wf->process_method( $invocant, $result )

Run the method associated with the workflow.

=item $wf->process( $invocant, $result )

Run the workflow including task sorting and template importing.

=item $wf->run_items( $invocant, $result, @items )

@items must contain workflow and/or task objects. Calls process() on all items.

=item $wf->run_items_parallel( $invocant, $result, @items )

Like run_items() except items are run in parrallel using L<Parallel::Runner>.

=item $wf->run_method( $invocant )

=item $wf->run_method( $invocant, $method )

Runs the specified method, or the method associated with the workflow. Runs the
method within an L<Method::Workflow::Method> object so that keywords know to
which workflow items should be added.

=item $invocant = $wf->get_invocant( $obj || %constructor_args )

Constructs a new instance of invocant_class. Alternatively if an object is
provided as an argument it will be returned as-is.

=item $wf->run_tasks( $invocant, $result, @tasks )

Takes care of ordering the tasks and running them, possibly in parallel.

=item $wf->handle_errors( $result )

Errors are all handled after tasks have been run.

=back

=head1 TEMPLATES

Any workflow or class with a root workflow can be used as a template.
Essentially any workflow that uses another as a template inherits from it.

=head1 SEE ALSO

=head2 TOOLS

=over 4

=item L<Exodist::Util>

This module provides a huge collection of utilites used to create Method::Workflow.

=item L<Method::Workflow::Subclass>

Any extension should make use of this to provide a keyword.

=item L<Method::Workflow::Result>

All workflow results are returned in a L<Method::Workflow::Result> object.

=item L<Method::Workflow::Method>

A special method that is blessed and associated with a workflow so that it can
be easily found in the stack.

=back

=head2 EXTENSIONS

=over 4

=item L<Method::Workflow::SPEC>

An implementation of Ruby's RSPEC.

=item L<Method::Workflow::Case>

Run multiple actions in multiple scenarios.

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
