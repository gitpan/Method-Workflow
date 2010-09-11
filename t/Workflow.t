#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Method::Workflow::Stack qw/:all/;

our $CLASS;
BEGIN {
    $CLASS = 'Method::Workflow';
    require_ok $CLASS;
    $CLASS->import;
}

isa_ok( $CLASS->new( name => 'a', method => sub {} ), $CLASS );

can_ok( __PACKAGE__, qw/ workflow task start_workflow / );

isa_ok( start_workflow(), $CLASS );
ok( !stack_peek, "Nothing on the stack" );

my @warnings;
throws_ok {
    local $SIG{__WARN__} = sub { push @warnings => @_ };
    Method::Workflow::default_error_handler(
        [
            [
                $CLASS->new(name => 'a1', method => sub {}),
                $CLASS->new(name => 'a2', method => sub {}),
            ],
            "Error A at file line 1"
        ],
        [
            [
                $CLASS->new(name => 'b1', method => sub {}),
                $CLASS->new(name => 'b2', method => sub {}),
            ],
            "Error B at file line 1"
        ],
    );
} qr/There were errors \(see above\)/,
    "error handler dies";

is_deeply(
    \@warnings,
    [
        "Error A at file line 1\n  Workflow Stack:\n  Method::Workflow(a1)\n  Method::Workflow(a2)\n",
        "Error B at file line 1\n  Workflow Stack:\n  Method::Workflow(b1)\n  Method::Workflow(b2)\n",
    ],
    "Correct messages"
);

my $one;
$one = $CLASS->new( name => 'test', method => sub {
    my ( $invocant, $workflow ) = @_;
    is( $invocant, 'a', "correct invocant" );
    is( $workflow, $one, "Got workflow" );
    is( stack_peek, $one, "Stack pushed" );
    return 'xxx';
});
ok( !stack_peek, "Nothing on the stack" );
$one->run( 'a' );
ok( !stack_peek, "Nothing on the stack" );
is_deeply( [ $one->results ], [ 'xxx' ], "Results" );

ok( !$one->observed, "Not observed" );
$one->observe(1);
ok( $one->observed, "Observed" );

ok( !stack_peek, "Nothing on the stack" );
$one->begin;
is( stack_peek, $one, "Stack pushed" );
$one->end;
ok( !stack_peek, "Nothing on the stack" );

$one->do( sub { is( stack_peek, $one, "Stack pushed" ) });
ok( !stack_peek, "Nothing on the stack" );

done_testing;
