use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# old version that works actually somewhat well...
sub version_compare {
    my ($a, $b) = @_;
    local $_;

    while ($a || $b) {
	my ($sb, $sa) =  map { $1 if $a =~ /^\W*\d/ ? s/^\W*0*(\d+)// : s/^\W*(\D*)// } ($b, $a);
	$_ = ($sa =~ /^\d/ || $sb =~ /^\d/) && length($sa) <=> length($sb) || $sa cmp $sb and return $_ || 0;
	$sa eq '' && $sb eq '' and return $a cmp $b || 0;
    }
    0;
}

my $libs = ' -lrpm -lrpmio ' . (version_compare(qx(rpm -q --qf %{VERSION} rpm), "4.0.3") >= 0 && "-lrpmdb ") . '-lpopt -lz -lbz2';

WriteMakefile(
    'NAME'      => 'rpmtools',
    'OPTIMIZE'  => '-O3 -fomit-frame-pointer -fno-exceptions -fno-rtti -pipe -s -ffast-math -fexpensive-optimizations',
    'MAKEFILE'  => 'Makefile_core',
    'OBJECT'    => 'rpmtools.o',
    'VERSION_FROM'   => 'rpmtools.pm',
    'LIBS'      => [$libs],   # e.g., '-lm' 
    'INC'       => '-I/usr/include/rpm',     # e.g., '-I/usr/include/other' 
);

