#!/usr/bin/perl;
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Exodist::Util::Accessors qw/:all/;
use Method::Workflow::Stack qw/:all/;

our $CLASS;
BEGIN {
    $CLASS = 'Method::Workflow';
    require_ok $CLASS;
    $CLASS->import();
}

{
    package WFTemplate;
    use strict;
    use warnings;
    BEGIN { $CLASS->import() }

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
}

# Run twice to check reusability
for ( 1 .. 2 ) {
    ok( !stack_peek, "Stack clear" );
    my $wf = start_workflow;
    is( stack_peek, $wf, "Stack set" );
    my $order = WFTemplate::insert_rainbow;
    is_deeply( $order, [], "Nothing yet" );
    my @out = $wf->run_workflow( undef, qw/results task_results/ );
    is_deeply(
        \@out,
        [
            [ 'rainbow complete', 'red complete', 'yellow complete', 'green complete', 'blue complete', ],
            [ qw/ red yellow green blue /],
        ],
        "Got results"
    );
    is_deeply(
        $order,
        [
            'rainbow complete', 'red complete', 'yellow complete', 'green complete', 'blue complete',
            'red', 'yellow', 'green', 'blue',
        ],
        "Order is correct",
    );
}

ok( !stack_peek, "Stack cleared" );

throws_ok { workflow OOPS { 1 } }
    qr/No current workflow, did you forget to run start_workflow\(\) or \$workflow->begin\(\)\?/,
    "Useful error";

done_testing;
