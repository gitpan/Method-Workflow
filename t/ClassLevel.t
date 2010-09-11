#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

BEGIN {
    package A;
    use Method::Workflow;
    our $WF = start_workflow;
    workflow A { 'A' }
}
BEGIN {
    package B;
    use Method::Workflow;
    our $WF = start_workflow;
    workflow B { 'B' }
}
BEGIN {
    package C;
    use Method::Workflow;
    our $WF = start_workflow;
    workflow C { 'C' }
}

use Method::Workflow;
my $WF = start_workflow;
workflow D { 'D' }

is( $WF->children, 1, "Stack system + Begin puts things in the correct place" );
is( $A::WF->children, 1, "Stack system + Begin puts things in the correct place" );
is( $B::WF->children, 1, "Stack system + Begin puts things in the correct place" );
is( $C::WF->children, 1, "Stack system + Begin puts things in the correct place" );

done_testing;
