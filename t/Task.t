#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

our $CLASS;
BEGIN {
    $CLASS = 'Method::Workflow::Task';
    require_ok $CLASS;
    $CLASS->import;
}

can_ok( __PACKAGE__, qw/ task / );
isa_ok( $CLASS, 'Method::Workflow' );

done_testing
