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
our $CLASS;
BEGIN {
    $CLASS = 'Method::Workflow';
    require_ok $CLASS;
    no warnings 'redefine';
    *Method::Workflow::shuffle = \&shuffle;
    $CLASS->import( ':random' );
}

sub insert_rainbow {
    my @order;
    workflow rainbow {
        workflow wred {
            task tred { push @order => 'red'; 'red' }
            push @order => 'red complete'; 'red complete';
        }
        workflow wyellow {
            task tyellow { push @order => 'yellow'; 'yellow' }
            push @order => 'yellow complete'; 'yellow complete';
        }
        workflow wgreen {
            task tgreen { push @order => 'green'; 'green' }
            push @order => 'green complete'; 'green complete';
        }
        workflow wblue {
            task tblue { push @order => 'blue'; 'blue' }
            push @order => 'blue complete'; 'blue complete';
        }
        push @order => 'rainbow complete'; 'rainbow complete';
    }
    return \@order;
}

my $order = insert_rainbow;
is_deeply( $order, [], "Nothing yet" );

#use Exodist::Util qw/package_subs blessed/;
#use Time::HiRes qw/sleep/;
#my $indent = 1;
#for my $name ( package_subs( 'Method::Workflow' )) {
#    next if grep { $name eq $_ } qw/ blessed shuffle finally try first catch /;
#
#    no warnings 'redefine';
#    no strict 'refs';
#    my $current = Method::Workflow->can($name);
#    *{"Method::Workflow::$name"} = sub {
#        my $wf = blessed($_[0]) ? ($_[0]->{name} || "unnamed") : "--";
#        $indent++;
#        print $wf . ( " " x $indent ) . "start $name\n";
#        if ( wantarray ) {
#            my @out = $current->( @_ );
#            $indent--;
#            print $wf . ( " " x $indent ) . "end $name\n";
#            sleep 0.05;
#            return @out;
#        }
#        else {
#            my $out = $current->( @_ );
#            $indent--;
#            print $wf . ( " " x $indent ) . "end $name\n";
#            sleep 0.05;
#            return $out;
#        }
#    }
#}

my $result = run_workflow();
is_deeply(
    $order,
    [
        'rainbow complete', 'red complete', 'yellow complete', 'green complete', 'blue complete',
        shuffle( 'red', 'yellow', 'green', 'blue' )
    ],
    "Order is correct",
);

$order = [];
my $wf = new_workflow test ( sorted => 1 ) { $order = insert_rainbow }
is_deeply( $order, [], "Nothing yet" );
$result = $wf->run( );
is_deeply(
    $order,
    [
        'rainbow complete', 'red complete', 'yellow complete', 'green complete', 'blue complete',
        sort 'red', 'yellow', 'green', 'blue'
    ],
    "Order is correct",
);

$order = [];
$wf = new_workflow root ( sorted => 1 ) {
    task c { push @$order => 'c' }
    task a { push @$order => 'a' }
    task b { push @$order => 'b' }
    task x { push @$order => 'x' }
    task 'y' { push @$order => 'y' }
    workflow w ( ordered => 1 ) {
        task f { push @$order => 'f' }
        task e { push @$order => 'e' }
        task d { push @$order => 'd' }
    }
    workflow z ( random => 1 ) {
        task g { push @$order => 'g' }
        task h { push @$order => 'h' }
        task i { push @$order => 'i' }
        task j { push @$order => 'j' }
    }
}
$wf->run();

is_deeply(
    $order,
    [ qw/ a b c f e d x y j g i h /],
    "Nested re-ordering"
);

done_testing;
