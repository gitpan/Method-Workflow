#!/usr/bin/perl;
use strict;
use warnings;

# In this case test count is important, do not use done_testing
# Some tests are inside workflows, if the workflows just didn't run we would
# not know.
use Test::More tests => 23;
use Method::Workflow::Stack qw/stack_current stack_parent/;
use Method::Workflow::Meta qw/meta_for/;

BEGIN {
    package WorkflowClass;
    use strict;
    use warnings;

    use Method::Workflow;
    use base 'Method::Workflow::Base';

    keyword 'wflow';
    $INC{'WorkflowClass.pm'} = __FILE__;
}

BEGIN {
    package TestBase;
    use strict;
    use warnings;
    use WorkflowClass;
    use Method::Workflow::Stack qw/stack_current stack_parent/;
    use Test::More;

    sub new {
        my $class = shift;
        bless( { @_ }, $class );
    }

    sub init {
        my $class = shift;

        wflow first {
            is( $self, $class, "got self for free" );
            is( stack_parent(), $class, "got parent" );
            my $first = $_[0];

            wflow nested {
                is( $self, $class, "got self for free" );
                is( stack_parent(), $first, "got parent" );

                wflow deep {
                    is( $self, $class, "got self for free" );
                    return 'deep';
                }

                return 'nested';
            }

            return 'first';
        }

        wflow second {
            wflow nestedA { 'nestedA' }
            wflow nestedB { 'nestedB' }
            'second';
        }
    }
}

BEGIN {
    package TestMagic;
    use strict;
    use warnings;
    use WorkflowClass ':classlevel';
    use Method::Workflow::Stack qw/stack_current stack_parent/;
    use Test::More;
    use base 'TestBase';

    is( stack_parent(), undef, "no parent" );

    __PACKAGE__->init();
}

BEGIN {
    package TestNoMagic;
    use strict;
    use warnings;
    use WorkflowClass;
    use Method::Workflow::Stack qw/stack_current stack_parent/;
    use Test::More;
    use base 'TestBase';

    is( stack_current(), undef, "no current" );
    start_class_workflow();

    is( stack_current(), __PACKAGE__, "current" );
    __PACKAGE__->init();

    end_class_workflow();
    is( stack_current(), undef, "no current" );
}

use WorkflowClass;

is_deeply(
    [ $_->run_workflow() ],
    [ qw/ first nested deep second nestedA nestedB / ],
    "Workflow Results",
) for qw/ TestMagic TestNoMagic /;

my $one;
$one = TestBase->new->wflow( 'obj', sub {
    my $self = shift;
    is( $self, $one, "got self" );
    is( $_[0], (meta_for($one)->items)[0], "Second param is object being run" );
    is( $_[0], stack_current(), "Second param is also current stack" );
    is( stack_parent(), $one, "got parent" );

    wflow nestedA {
        wflow deep { 'deep' }
        'nestedA'
    }

    wflow nestedB { 'nestedB' }

    'obj';
});

is_deeply(
    [ $one->run_workflow() ],
    [ qw/ obj nestedA deep nestedB /],
    "OO Form",
);

$one = TestBase->new->wflow( "aaa", sub {
    wflow b {
        wflow c {
            wflow d {
                wflow e {
                    return stack_current();
                }
            }
        }
    }
});

my @out = $one->run_workflow;
my $trace = $out[-1]->parent_trace();

is(
    $trace . "\n",
    <<"    EOT",
  WorkflowClass - 'e'
  WorkflowClass - 'd'
  WorkflowClass - 'c'
  WorkflowClass - 'b'
  WorkflowClass - 'aaa'
  $one
    EOT
  "Trace"
);

my $save;
$one = TestBase->new->wflow( "aaa", sub {
    die "The error";
});
$one->error_handler( sub {
    ( my $owner, my $root, $save ) = @_
});
$one->run_workflow;
like( $save, qr/The error at/, "Error Handler" );
