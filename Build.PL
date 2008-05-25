use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Time::Normalize',
    license             => 'perl',
    dist_author         => 'Eric J. Roode <roode@cpan.org>',
    dist_version_from   => 'lib/Time/Normalize.pm',
    build_requires =>
    {
     'Test::More'      =>  '0.40',
    },
    sign => 1,
    add_to_cleanup      => [ 'Time-Normalize-*' ],
);

$builder->create_build_script();
