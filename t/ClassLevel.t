#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

BEGIN {
    package A;
    use Method::Workflow;
    workflow A { 'A' }
}
BEGIN {
    package B;
    use Method::Workflow;
    workflow B { 'B' }
}
BEGIN {
    package C;
    use Method::Workflow;
    workflow C { 'C' }
}

use Method::Workflow;
workflow D { 'D' }

is( root_workflow()->children,  1, "Correct Place" );
is( A->root_workflow->children, 1, "Correct Place" );
is( B->root_workflow->children, 1, "Correct Place" );
is( C->root_workflow->children, 1, "Correct Place" );

done_testing;
