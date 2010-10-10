package Method::Workflow::SubClass;
use strict;
use warnings;
use Exporter::Declare qw/ -magic -all /;
use Devel::Caller qw/ caller_cv /;
use Exodist::Util qw/
    inject_sub
    blessed
/;

sub Workflow { 'Method::Workflow'         }
sub Method   { 'Method::Workflow::Method' }

default_exports qw/
    parent_workflow
    keyword
/;

export_tag nobase => qw/ -default /;

sub after_import {
    my $class = shift;
    my ( $caller, $specs ) = @_;

    return 1 if $specs->config->{'nobase'};

    Exporter::Declare->export_to( $caller, qw/export_to/ );
    Exporter::Declare::export_to(
        'Exporter::Declare::Magic',
        $caller,
        qw/export default_export/
    );

    no strict 'refs';
    push @{"$caller\::ISA"} => Workflow();
}

sub parent_workflow {
    my $level = 0;

    my $package;
    while ( my @caller = caller($level)) {
        last if $caller[7]; # Last if the call is a require
        my $sub = caller_cv($level);
        $package = $caller[0] if !$package && $caller[0]->can('root_workflow');
        $level++;

        return $sub->workflow()
            if blessed( $sub )
            && blessed( $sub )->isa( Method() );

        my @next = caller($level);

        return $caller[0]->root_workflow
            if $next[7] #if next call is a require
    }

    return $package->root_workflow;
}

sub keyword {
    my ( $keyword, $createclass ) = @_;
    my $wfclass = caller;
    $createclass ||= $wfclass;

    inject_sub( $wfclass, 'keyword', sub { $keyword }, 1 );

    $wfclass->default_export(
        $keyword,
        'fennec',
        sub {
            my $name = shift;
            my ( $method, %proto ) = _method_proto( @_ );

            my ( $caller, $file, $line ) = caller;

            parent_workflow()->add_item(
                $createclass->new(
                    %proto,
                    name => $name || undef,
                    method => $method || undef,
                    end_line => $line || undef,
                ),
            );
        }
    );
}

sub _method_proto {
    return ( $_[0] ) if @_ == 1;
    my %proto = @_;
    return ( $proto{ method }, %proto );
}

1;

=head1 NAME

Method::Workflow::SubClass - Provides tools for Workflow and extensions.

=head1 IMPORTING

=head2 AUTOMATIC @ISA MANIPULATION

When you use Method::Workflow::SubClass the importing class is autamatically
turned into a subclass of L<Method::Workflow>. This is the same as if you had
typed 'use base qw/Method::Workflow/'.

To prevent this behavior import Method::Workflow::SubClass with the ':nobase'
parameter:

    use Method::Workflow::SubClass ':nobase';

=head2 EXPORTS

=over 4

=item keyword( $name )

=item keyword( $name, $class )

Define a keyword to be exported by the calling class. The keyword will take a
name and codeblock. It will use the name and blck to create a new instance of
$class or your class and add it to the current workflow using
$workflow->additem()

=item $wf = parent_workflow()

Search back through the stack to find the current workflow.

=back

=head1 FENNEC PROJECT

This module is part of the Fennec project. See L<Fennec> for more details.
Fennec is a project to develop an extensible and powerful testing framework.
Together the tools that make up the Fennec framework provide a potent testing
environment.

The tools provided by Fennec are also useful on their own. Sometimes a tool
created for Fennec is useful outside the greater framework. Such tools are
turned into their own projects. This is one such project.

=over 2

=item L<Fennec> - The core framework

The primary Fennec project that ties them all together.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Method-Workflow is free software; Standard Perl license.

Method-Workflow is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
