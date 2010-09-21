#!/usr/bin/perl
use strict;
use warnings;

use Fennec::Lite;

our $CLASS;
BEGIN {
    $CLASS = 'Method::Workflow';
    require_ok $CLASS;
    $CLASS->import;
}

tests "import and construction" => sub {
    isa_ok( $CLASS->new( name => 'a', method => sub {} ), $CLASS );

    can_ok( __PACKAGE__, qw/ workflow task  / );

    isa_ok( new_workflow a {}, $CLASS );
};

tests "method params" => sub {
    my $one;
    $one = $CLASS->new( invocant_class => __PACKAGE__, name => 'test', method => sub {
        my ( $invocant, $workflow ) = @_;
        is_deeply( $invocant, { a => 1 }, "correct invocant" );
        isa_ok( $invocant, __PACKAGE__ );
        is( $workflow, $one, "Got workflow" );
    });
    $one->run( a => 1 );
};

run_tests;
done_testing;
