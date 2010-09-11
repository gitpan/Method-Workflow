#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Exporter::Declare ':all';

BEGIN {
    require_ok( 'Method::Workflow::Stack' );
    Method::Workflow::Stack->import( ':all' );
}

can_ok( __PACKAGE__, qw/
    keyword

    stack_push
    stack_pop
    stack_peek
    stack_trace
/);

keyword 'test';
is( __PACKAGE__->keyword, 'test', "rewrote keyword" );
{ package AAAA; main->import() }
can_ok( 'AAAA', 'test' );

{
    package Method::Workflow;
    use strict;
    use warnings;
    use Exodist::Util qw/accessors/;

    accessors qw/name _acting_parent/;

    sub new {
        my $class = shift;
        return bless( {@_}, $class );
    }
}

# Stack holds weak refs, we need to hold them here.
my @refs;
sub wf { push @refs => Method::Workflow->new( @_ ); $refs[-1]}
isa_ok( wf, 'Method::Workflow' );

stack_push( wf( _acting_parent => 1, name => "bad 1" ));
stack_push( wf( name => "bad 2" ));
stack_push( wf( _acting_parent => 1, name => "good root" ));
stack_push( wf( name => "good 1" ));
stack_push( wf( name => "good 2" ));
stack_push( wf( name => "good 3" ));
is( stack_peek->name, 'good 3', "correct stack top" );

is_deeply(
    stack_trace,
    [ @refs[3 .. 6] ],
    "useful trace",
);

stack_pop( $refs[-1]);

is( stack_peek->name, 'good 2', "correct stack top" );

done_testing;
