#!/usr/bin/perl;
use strict;
use warnings;

# Reproducable shuffle for test predictability
# We only need to test that results are shuffled, we don't need a good shuffle
# algorith here, just a consistant (and thusly bad) one
sub shuffle (@) {
    my @in = @_;
    my @out;
    while( @in ) {
        push @out => pop( @in );
        push @out => shift( @in ) if @in;
    }
    return @out;
}

use Test::More;
use Method::Workflow::Stack qw/:all/;
our $CLASS;
BEGIN {
    $CLASS = 'Method::Workflow';
    require_ok $CLASS;
    no warnings 'redefine';
    *Method::Workflow::shuffle = \&shuffle;
    $CLASS->import();
}

sub insert_rainbow {
    my @order;
    workflow rainbow {
        workflow red {
            task red { push @order => 'red'; 'red' }
            push @order => 'red complete'; 'red complete';
        }
        workflow yellow {
            task yellow { push @order => 'yellow'; 'yellow' }
            push @order => 'yellow complete'; 'yellow complete';
        }
        workflow green {
            task green { push @order => 'green'; 'green' }
            push @order => 'green complete'; 'green complete';
        }
        workflow blue {
            task blue { push @order => 'blue'; 'blue' }
            push @order => 'blue complete'; 'blue complete';
        }
        push @order => 'rainbow complete'; 'rainbow complete';
    }
    return \@order;
}

my $wf = start_workflow( random => 1 );
my $order = insert_rainbow;
is_deeply( $order, [], "Nothing yet" );
my @out = $wf->run_workflow( undef, qw/results task_results/ );
is_deeply(
    $order,
    [
        'rainbow complete', 'red complete', 'yellow complete', 'green complete', 'blue complete',
        shuffle( 'red', 'yellow', 'green', 'blue' )
    ],
    "Order is correct",
);

$wf = start_workflow( sorted => 1 );
$order = insert_rainbow;
is_deeply( $order, [], "Nothing yet" );
@out = $wf->run_workflow( undef, qw/results task_results/ );
is_deeply(
    $order,
    [
        'rainbow complete', 'red complete', 'yellow complete', 'green complete', 'blue complete',
        sort 'red', 'yellow', 'green', 'blue'
    ],
    "Order is correct",
);

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

done_testing;
