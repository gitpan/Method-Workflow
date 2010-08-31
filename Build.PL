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
        'Scalar::Util' => 0,
        'Try::Tiny' => 0,
        'Exporter::Declare' => '0.024',
        'perl' => 5.008,
        'Hook::AfterRuntime' => '0.005',
        'Carp' => 0,
    },
    build_requires => {
        'Test::More' => 0.88,
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
