use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $libs = ' -lrpm -lrpmio -lpopt -lz -lbz2';

WriteMakefile(
    'NAME'      => 'rpmtools',
    'OPTIMIZE'  => '-O3 -fomit-frame-pointer -fno-exceptions -fno-rtti -pipe -s -ffast-math -fexpensive-optimizations',
    'MAKEFILE'  => 'Makefile_core',
    'OBJECT'    => 'rpmtools.o',
    'VERSION_FROM'   => 'rpmtools.pm',
    'LIBS'      => [$libs],   # e.g., '-lm' 
    'INC'       => '-I/usr/include/rpm',     # e.g., '-I/usr/include/other' 
);

