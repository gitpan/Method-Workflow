package Method::Workflow;
use strict;
use warnings;

use Exporter::Declare ':extend :all';
use Method::Workflow::Stack qw/stack_current stack_pop stack_push/;
use Method::Workflow::Meta qw/meta_for/;
use Devel::Declare::Parser::Fennec;
use Scalar::Util qw/ blessed /;
use Carp qw/confess/;
use Try::Tiny;

our $VERSION = '0.007';
our @EXPORT = qw/export export_ok export_to import accessors /;
our @EXPORT_OK = qw/ handle_error run_workflow meta_shortcuts /;
our @META_SHORTCUTS = qw/ error_handler task_runner /;

sub meta_shortcuts { @META_SHORTCUTS }

for my $ms ( @META_SHORTCUTS ) {
    export_ok( $ms, 'codeblock', sub {
        my $owner = blessed( $_[0] )
            ? shift( @_ )
            : stack_current;
        my ( $code ) = @_;
        meta_for( $owner )->prop( $ms, $code );
    });
}

sub _method_proto {
    return ( $_[0] ) if @_ == 1;
    my %proto = @_;
    return ( $proto{ method }, %proto );
}

export keyword {
    my ( $keyword ) = @_;
    my $workflow = caller;

    {
        no strict 'refs';
        no warnings 'redefine';
        *{"$workflow\::keyword"} = sub { $keyword };
    }

    $workflow->export(
        $keyword,
        'fennec',
        sub {
            my ( $owner, $return_owner );
            if ( blessed( $_[0] )) {
                $owner = shift( @_ );
                $return_owner = 1;
            }
            else {
                $owner = stack_current;
                $return_owner = 0;
            }

            my $name = shift;

            my ( $method, %proto ) = _method_proto( @_ );

            meta_for($owner)->add_item(
                $workflow->new(
                    %proto,
                    name => $name || undef,
                    method => $method || undef,
                    parent => $owner,
                ),
            );

            return $owner if $return_owner;
            return;
        }
    );
};

sub accessors {
    my $caller = caller;
    for my $name ( @_ ) {
        my $sub = sub {
            my $self = shift;
            ( $self->{$name} ) = @_ if @_;
            return $self->{$name};
        };
        no strict 'refs';
        *{"$caller\::$name"} = $sub;
    }
}

sub handle_error {
    my ( $current, $root, @errors ) = @_;

    my ( $caller, $file, $line ) = caller;
    $file =~ s|.*/lib/|...|g;
    my $handler = meta_for( $current )->prop( 'error_handler' )
               || meta_for( $root )->prop( 'error_handler' )
               || sub {
                   die
                    join( ' ', @errors )
                    . "\n  $file line $line\n"
               };

    $handler->( $current, $root, @errors );
}

sub run_workflow {
    my ( $current, $root ) = @_;
    $current ||= caller;
    $root ||= $current;
    my $meta = meta_for( $current );
    my $out = [];

    try {
        stack_push( $current );

        _run_current( $current, $root, $out)
            if blessed( $current )
            && $current->isa( 'Method::Workflow::Base' );

        _run_pre_run_hooks( $current, $root, $meta );
        _run_children( $current, $root, $meta, $out );
        _run_tasks( $current, $root, $meta, $out );
        _run_post_run_hooks( $current, $root, $meta, $out );

        stack_pop( $current );
    }
    catch {
        stack_pop( $current );
        handle_error( $current, $root, $_ )
    };

    return @$out;
}

sub _run_current {
    my ( $current, $root, $out ) = @_;
    $current->observe();
    try   { push @$out => $current->run( $root )}
    catch { handle_error( $current, $root, $_  )}
}

sub _run_pre_run_hooks {
    my ( $current, $root, $meta ) = @_;

    for my $hook ( $meta->pre_run_hooks ) {
        try { $hook->(
            current => $current,
            meta  => $meta,
            root  => $root,
        )} catch { handle_error( $current, $root, $_ )}
    }
}

sub _run_children {
    my ( $current, $root, $meta, $out ) = @_;
    for my $item ( $meta->items ) {
        try   { push @$out => $item->run_workflow( $root )}
        catch { handle_error( $current, $root, $_ )        }
    }
}

sub _run_tasks {
    my ( $current, $root, $meta, $out ) = @_;

    return unless $meta->tasks;
    my $TASK = 'Method::Workflow::Task';

    for my $key ( $meta->task_keys ) {
        my @tasks = $meta->pull_tasks( $key );
        my $specs = $meta->prop( $key );
        my ($order) = $specs ? grep { $specs->{$_} } $TASK->order_options
                             : (undef);

        my $task = $TASK->new(
            subtasks_ref => \@tasks,
            _ordering => $order,
        );

        try { push @$out => $task->run_task()     }
        catch { handle_error( $task, $current, $_, )};
    }
}

sub _run_post_run_hooks {
    my ( $current, $root, $meta, $out ) = @_;
    for my $hook ( $meta->post_run_hooks ) {
        try { $hook->(
            current => $current,
            meta  => $meta,
            root  => $root,
            out   => $out,
        )} catch { handle_error( $current, $root, $_ )}
    }
}

1;

=head1 NAME

Method::Workflow - Create classes that provide workflow method keywords.

=head1 DESCRIPTION

In this module a workflow is a sequence of methods, possibly nested, associated
with an object or class, that can be programmatically generated, chained or
mixed.

Generally you declare workflow methods as small parts of a greater design. A
good example of what this module attemps to achieve is Ruby's RSPEC
L<http://rspec.info/>. However workflows need not be restricted to testing.

B<Example workflow (L<Method::Workflow::Case>):>

Each 'task' method will be run for each 'case' method

    my $target;
    case a { $target = "case 1" }
    case b { $target = "case 2" }
    case c { $target = "case 2" }

    action display { print "$target\n" }
    action display_cap { print uc($target) . "\n" }

    run_workflow();

Prints:

    case 1
    CASE 1
    case 2
    CASE 2
    case 3
    CASE 3

=head1 SYNOPSYS

There are 2 parts to this, the first is creating workflow element classes which
export keywords to define workflow methods. The other part is using workflow
element classes to construct workflows.

=head2 WORKFLOW ELEMENTS

SimpleWorkflowClass.pm:

    package SimpleWorkflowClass;
    use strict;
    use warnings;

    use Method::Workflow;
    use base 'Method::Workflow::Base';

    accessors qw/ my_accessor_a my_accessor_b /;

    keyword 'wflow';

    sub run {
        my $self = shift;
        my ( $root ) = @_;
        ...
        return $self->method->( $element, $self );
    }

Explanation:

=over 4

=item use Method::Workflow

This imports the 'keyword' keyword that is used later.

=item use base 'Method::Workflow::Base'

You must subclass L<Method::Workflow::Base> or another class which inherits
from it.

=item accessors qw/ my_accessor_a my_accessor_b /

Method::Workflow exports the 'accessors' function by default. This is a simple
get/set accessor generator. Nothing forces you to use this in favor of say
L<Moose>, but it is available to keep your classes light-weight.

=item keyword 'wflow'

Here we declare a keyword to export that inserts a new object of this class
into the workflow being generated when the 'wflow' keyword is used.

=item sub run { ... }

This is what is called to run the method contained in this workflow, you could
hijack it to do other things as well / instead.

=item $self->method->( $element, $self )

The method is a method on the class for which the worflow was created, not for
the instance of the element, thus the firs argumunt should be the root
object/class.

=back

=head2 DECLARING WORKFLOWS

Workflows run from the root (class/object) up. Nested items are run in order
after the item in which they are defined. Each item runs, and runs it's
children before returning and allowing it's siblings to run.

Simple Example:

    wflow root {
        ...
        wflow nested {
            ...
        }
    }

=head3 WORKFLOW ARGUMENTS

Workflows are given 2 arguments. The first argument is the object/class that is
the root element of the workflow. The second argument is the workflow instance
being run. When a workflow is defined using a keyword, the first argumunt will
automatically be shifted off as $self.

=head3 CLASS LEVEL (NO MAGIC)

ClassWithWorkflow.pm:

    package ClassWithWorkflow;
    use strict;
    use warnings;
    use WorkflowClass;

    start_class_workflow();

    wflow first {
        # $self is shifted for you for free. This is a class-level workflow so
        # $self will be the class name: 'ClassWithWorkflow'
        $self->do_thing;

        wflow nested {
            wflow deep { 'deep' }
            return 'nested';
        }
        return 'first';
    }

    wflow second {
        wflow nestedA { 'nestedA' }
        wflow nestedB { 'nestedB' }
        return 'second';
    }

    # Forgetting this can be dire, thats what the magic in the next section is
    # for.
    end_class_workflow();

    1;

my_script.t:

    #!/usr/bin/perl
    use strict;
    use warnings;
    use Data::Dumper;
    use ClassWithWorkflow;

    my @results = ClassWithWorkflow->run_workflow();
    print Dumper \@results;

Results:

    $ perl my_script.t
    $VAR1 = [
        'first',
        'nested',
        'deep',
        'second',
        'nestedA',
        'nestedB',
    ];

=head3 CLASS LEVEL (MAGIC)

B<Note> The magic comes from L<Hook::AfterRuntime>  B<read the caveats section
of its documentation>. If you do not understand these limitations they may bite
you. See the 'CLASS LEVEL (NO MAGIC)' section below if you need te work around
any issues.

ClassWithWorkflow.pm:

    package ClassWithWorkflow;
    use strict;
    use warnings;
    use WorkflowClass qw/ :classlevel /;

    wflow first {
        # $self is shifted for you for free. This is a class-level workflow so
        # $self will be the class name: 'ClassWithWorkflow'
        $self->do_thing;

        wflow nested {
            wflow deep { 'deep' }
            return 'nested';
        }
        return 'first';
    }

    wflow second {
        wflow nestedA { 'nestedA' }
        wflow nestedB { 'nestedB' }
        return 'second';
    }

    sub new {
        my $class = shift;
        bless( { @_ }, $class );
    }

    1;

my_script.t:

    #!/usr/bin/perl
    use strict;
    use warnings;
    use Data::Dumper;
    use ClassWithWorkflow;

    my @results = ClassWithWorkflow->run_workflow();
    print Dumper \@results;

Results:

    $ perl my_script.t
    $VAR1 = [
        'first',
        'nested',
        'deep',
        'second',
        'nestedA',
        'nestedB',
    ];


=head3 IN AN OBJECT

ObjectWithWorkflow.pm:

    package ObjectWithWorkflow;
    use strict;
    use warnings;

    # import the 'wflow' keyword which also works as a method!
    use WorkflowClass;

    sub new {
        my $class = shift;
        bless( { @_ }, $class );
    }

    sub insert_useless_workflow {
        my $self = shift;

        # Keyword form inserts it to the active element, $self->wflow(...)
        # would insert it into the root workflow for the object, which is not
        # what we want.
        wflow useless { "useless" }
    }

    1;

my_script.t:

    #!/usr/bin/perl
    use strict;
    use warnings;
    use Data::Dumper;
    use ObjectWithWorkflow;

    my $obj = ObjectWithWorkflow->new;

    $obj->wflow( 'My Workflow', sub {
        # Not automatic in this form
        my $self = shift;

        $self->insert_useless_workflow();

        wflow {
            # $self is shifted for you for free because keyword was used. This
            # is an object workflow so $self will be the instance ($obj)
            $self->do_thing;

            'nested'
        }
        return 'my workflow';
    });

    print Dumper [ $obj->run_workflow() ];

Results:

    $ perl my_script.t
    $VAR1 = [
        'my workflow',
        'useless',
        'nested',
    ];

=head3 BOTH

A package can have both a class level workflow and object level workflows, it
just works.

=head3 WORKFLOW 'ROLES'

You can create the equivilent of a Moose role for workflows. Define a class
that has a subroutine that defines the workflow components you want to re-use.
Call the subroutine within the workflows that are to reuse it.

    {
        package WorkflowRole;
        use WorkflowClass;

        sub reusable {
            my $class = shift;
            my ($arg) = @_;
            wflow { print "I am reusable! Arg: $arg\n" }
        }
    }

    {
        package RoleConsumerA;
        use WorkflowClass;

        start_class_workflow;
        WorkflowRole->reusable( 'A' );
        end_class_workflow;
    }

    {
        package RoleConsumerB;
        use WorkflowClass;

        start_class_workflow;
        WorkflowRole->reusable( 'B' );
        end_class_workflow;
    }

    RoleConsumerA->run_workflow;
    RoleConsumerB->run_workflow;

Results:

    I am reusable! Arg: A
    I am reusable! Arg: B

=head2 TASKS

Within workflows you may define tasks. Tasks are just like workflows except
that tey are added to the root of the running workflow as opposed to the
current element. Tasks run after the workflow has completed.

To define tasks:

    wflow root {
        print "root\n";
        task a { print "a\n" }

        wflow nested {
            print "nested\n";
            task c { print "c\n }

            wflow deep {
                print "deep\n";
            }
        }

        task b { print "b\n }

        wflow nested2 {
            print "nested2\n";
        }
    }

Results (run order):

    root
    nested
    deep
    nested2
    a
    b
    c

=head3 ORDERING TASKS

You can sort or shuffle tasks. You can specify order as an import flag. The
default is 'ordered' which will run them in the order they were defined.

Shuffled:

    use WorkflowClass ':random';

Sorted by name:

    use WorkflowClass ':sorted';

B<Note>: Some more advanced workflows may make use of an ordering param on a
workflow:

    wflow name ( sorted => 1 ) { ... }

All Mothod::Workflow::Base objects have the 'ordered', 'sorted', and 'random'
attributes for your workflow to query.

=head1 SEE ALSO

=over 4

=item L<Method::Workflow::Base>

The base class all workflows must inherit from

=item L<Method::Workflow::Stack>

The stack class that tracks what class/object/element to which new workflow
element instances should be added.

=item L<Method::Workflow::Case>

Run tasks against multiple scenarios.

=item L<Method::Workflow::SPEC>

An RSPEC based workflow.

=back

=head1 NOTES

=over 4

=item Why is it called Method-Workflow

Each workflow element is a method that runs on the object for which it is
defined thus it is a workflow of methods.

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
