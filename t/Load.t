#!/usr/bin/perl
use strict;
use warnings;
use Fennec::Lite;

require_ok $_ or die for qw/
    Method::Workflow
    Method::Workflow::Task
    Method::Workflow::Result
    Method::Workflow::SubClass
    Method::Workflow::Method
/;

done_testing;
