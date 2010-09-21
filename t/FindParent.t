#!/usr/bin/perl
use strict;
use warnings;

use lib qw{ t/lib lib };

use Fennec::Lite;

use Method::Workflow;
use Method::Workflow::SubClass ':nobase';

workflow root {
    my ( $wf ) = @_;
    require ParentTest;
    workflow x { 'x' }

    my @children = $wf->children;
    is( @children, 1, "One child" );
    is( $children[0]->name, 'x', "Correct Child" );
}

my @children = root_workflow->children;
is( @children, 1, "One child" );
is( $children[0]->name, 'root', "Correct Child" );

run_workflow;

{
    no warnings 'once';
    is( $ParentTest::PARENT, ParentTest->root_workflow, "Correct parent in nested require" );
}
@children = ParentTest->root_workflow->children;
is( @children, 1, "One child" );
is( $children[0]->name, 'child', "Correct Child" );

my $result = Method::Workflow::Result->new();
$children[0]->process_method( bless({}, __PACKAGE__), $result);
@children = $children[0]->children;
is( @children, 1, "One subchild" );
is( $children[0]->name, 'subchild', "Correct subchild" );

run_tests;
done_testing;
