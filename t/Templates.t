#!/usr/bin/perl;
use strict;
use warnings;

use Fennec::Lite;
use Method::Workflow;

BEGIN {
    package Method::Template;
    use Method::Workflow;

    workflow a { 'a' }
    workflow b { 'b' }
    workflow c { 'c' }

    $INC{'Method/Template.pm'} = __FILE__;
}

my $tmp = new_workflow template {
    workflow d { 'd' }
    workflow d { 'e' }
    workflow d { 'f' }
};

import_templates qw/ Method::Template /, $tmp;

my $result = run_workflow();

is_deeply(
    $result->return_ref,
    [ qw/ a b c d e f /],
    "Imported Template"
);

done_testing;
