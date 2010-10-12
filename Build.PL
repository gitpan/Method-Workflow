#!/usr/bin/perl
use 5.008;
use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    module_name => 'Method::Workflow',
    license     => 'perl',
    dist_author => 'Chad Granum <exodist7@gmail.com>',
    create_readme => 1,
    requires => {
        'Try::Tiny' => 0,
        'Exporter::Declare' => '0.102',
        'Exodist::Util' => '0.007',
        'Devel::Declare::Parser::Fennec' => '0.004',
        'perl' => 5.008,
        'Carp' => 0,
        'Devel::Caller' => '2.05',
    },
    recommonds => {
        'Parallel::Runner' => '0.009',
    },
    build_requires => {
        'Fennec::Lite' => '0.004',
        'Test::More' => 0.88,
        'Test::Exception' => 0,
    },
    meta_merge => {
        resources => {
            repository => 'http://github.com/exodist/Method-Workflow',
            bugtracker => 'http://github.com/exodist/Method-Workflow/issues',
            homepage   => 'http://open-exodus.net/projects/Method-Workflow'
        },
    }
);

$build->create_build_script;
