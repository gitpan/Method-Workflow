package Method::Workflow;
use strict;
use warnings;

use Exporter::Declare ':extend :all';
use Method::Workflow::Stack qw/stack_current stack_pop stack_push/;
use Method::Workflow::Meta qw/meta_for/;
use Devel::Declare::Parser::Fennec;
use Scalar::Util qw/ blessed /;
use Carp qw/confess/;

our $VERSION = '0.003';
our @EXPORT = qw/export export_ok export_to import/;

sub _method_proto {
    return ( $_[0] ) if @_ == 1;
    my %proto = @_;
    return ( $proto{ method }, %proto );
}

export keyword {
    my ( $keyword ) = @_;
    my $workflow = caller;

    $workflow->export(
        $keyword,
        'fennec',
        sub {
            my $owner = blessed( $_[0] )
                ? shift( @_ )
                : stack_current;
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

            return $owner;
        }
    );
};

export accessors {
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

1;

=head1 NAME

Method::Workflow - Create classes that provide workflow method keywords.

=head1 DESCRIPTION

In this module a workflow is a sequence of methods, possibly nested, associated
with an object or class, that can be programmatically generated, chained or
mixed.

Generally you declare workflow methods as small parts of a greater design. A
good example of what this module attemps to achieve is Ruby's RSPEC
L<http://rspec.info/>. Howover workflows need not be restricted to testing.

B<Example workflow (L<Method::Workflow::Case>):>

Each 'task' method will be run for each 'case' method

    my $target;
    case a { $target = "case 1" }
    case b { $target = "case 2" }
    case c { $target = "case 2" }

    task display { print "$target\n" }

    run_workflow();
    # Prints:
    # case 1
    # case 2
    # case 3

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

=head3 CLASS LEVEL (NO MAGIC)

ClassWithWorkflow.pm:

    package ClassWithWorkflow;
    use strict;
    use warnings;
    use WorkflowClass;

    start_class_workflow();

    wflow first {
        # $self is shifted for you for free.
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
        # $self is shifted for you for free.
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
        my $self = shift;

        $self->insert_useless_workflow();

        wflow { 'nested' }
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
