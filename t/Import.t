#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Method::Workflow::Stack qw/stack_current/;
use Method::Workflow::Meta qw/meta_for/;

BEGIN {
    require_ok( 'Method::Workflow::Stack' );
    require_ok( 'Method::Workflow'        );
    require_ok( 'Method::Workflow::Base'  );
}

BEGIN {
    package Test::Workflow;
    use strict;
    use warnings;
    use Method::Workflow;
    use base 'Method::Workflow::Base';

    keyword 'twork';
    $INC{ 'Test/Workflow.pm' } = __FILE__;
}

BEGIN {
    package Test::UseWorkflowA;
    use strict;
    use warnings;
    use Test::More;
    use Method::Workflow::Stack qw/stack_current/;
    use Method::Workflow::Meta qw/meta_for/;
    BEGIN {
        ok( meta_for(), "Got a root" );
        ok( !stack_current, "No active stack yet" );
    }
    use Test::Workflow qw/:classlevel/;
    {
        use Test::Workflow qw/:classlevel/;
        is( @Method::Workflow::Stack::STACK, 1, "limited depth" );
    }

    can_ok( __PACKAGE__, 'twork', 'run_workflow' );
    is( stack_current(), __PACKAGE__, "Stack set" );
}

{
    package Test::UseWorkflowB;
    use strict;
    use warnings;
    use Test::More;
    use Method::Workflow::Stack qw/stack_current/;
    use Method::Workflow::Meta qw/meta_for/;
    BEGIN {
        ok( meta_for(), "Got a root" );
        ok( !stack_current, "No active stack yet" );
    }
    use Test::Workflow qw/:classlevel/;
    {
        use Test::Workflow qw/:classlevel/;
        is( @Method::Workflow::Stack::STACK, 1, "limited depth" );
    }

    can_ok( __PACKAGE__, 'twork', 'run_workflow' );
    is( stack_current(), __PACKAGE__, "Stack set" );
}

ok( !stack_current, "Stack cleared" );

done_testing();
