#!/usr/bin/perl;
use strict;
use warnings;

use Fennec::Lite;
use Exodist::Util::Accessors qw/:all/;

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
    my $order;
    my $wf = new_workflow test { $order = WFTemplate::insert_rainbow; 'root' };
    is_deeply( $order, undef, "Nothing yet" );
    my $result = $wf->run();
    is_deeply(
        $result,
        {
            return_ref => [
                'root', 'rainbow complete', 'red complete', 'yellow complete',
                'green complete', 'blue complete',
            ],
            task_return_ref => [ qw/ red yellow green blue /],
            errors_ref => [],
            tasks_ref => [],
        },
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

done_testing;
