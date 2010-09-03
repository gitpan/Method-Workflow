#!/usr/bin/perl;
use strict;
use warnings;

use Test::More;
use Method::Workflow::Task;

BEGIN {
    package WorkflowClass;
    use strict;
    use warnings;

    use Method::Workflow;
    use base 'Method::Workflow::Base';

    keyword 'wflow';
    $INC{'WorkflowClass.pm'} = __FILE__;
}

use WorkflowClass;

my @ran;

start_class_workflow;

wflow a {
    push @ran => 'a';

    wflow b {
        push @ran => 'b';

        wflow c {
            push @ran => 'c';
            task e { push @ran => 'e' }
            push @ran => 'c2';
        }

        task d { push @ran => 'd' }

        push @ran => 'b2';
    }

    push @ran => 'a2';
}

end_class_workflow;

run_workflow;

is_deeply(
    \@ran,
    [qw/ a a2 b b2 c c2 d e /],
    "Ran tasks"
);

done_testing;
