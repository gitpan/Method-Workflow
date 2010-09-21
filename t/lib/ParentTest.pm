package ParentTest;
use strict;
use warnings;

use Method::Workflow;
use Method::Workflow::SubClass ':nobase';

our $PARENT = parent_workflow();

workflow child {
    workflow subchild { 'b' }
    'a';
}

1;
