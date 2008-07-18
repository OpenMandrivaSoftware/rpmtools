# $Id$

use strict;
use ExtUtils::MakeMaker;

my $rpmtools_version = "5.6";

# where to find the rpm utility

my $rpm_path = $ENV{RPM_PATH}; # this overrides

unless (defined $rpm_path) {
    for (qw(/bin/rpm /usr/bin/rpm)) {
	if (-x) {
	    $rpm_path = $_;
	    last;
	}
    }
}

defined $rpm_path or die "Can't find rpm on this system\n";

sub hexversion {
	my ($major, $minor, $micro) = (@_[0] =~ /(\d+)\.(\d+)\.?(\d+)?/);
	return int($major<<16) + int($minor<<8) + int($micro<<0)
}

my $version = `LC_ALL=C $rpm_path --version`;
# fix compiling with RCs:
$version =~ s/(-.*)|(\.DEVEL)//;
chomp $version;
$version =~ s/(RPM version )|(rpm \(RPM\) )//;
my $hversion = hexversion($version);

my @rpmflags;
if ($hversion ge hexversion("4.4.90") && $hversion lt hexversion("4.5")) {
    # rpm.org version
    push @rpmflags, "-DRPM_ORG";
} else {
    # rpm5.org version
	push @rpmflags, "-DRPM_VERSION_CODE=$hversion";
}
my $ccflags = join(' ', '-Wall -fno-strict-aliasing', @rpmflags);

print "Found RPM version $version (compiling with flags: $ccflags)\n";

sub MY::postamble {
    <<MAKEMAKEFILE;
.PHONY: ChangeLog

\$(FROMCC): %: %.cc
	\$(CXX) \$(CCFLAGS) \$(OPTIMIZE) -DVERSION_STRING=\\"\$(RPMTOOLSVERSION)\\" $ccflags \$< \$(LIBRPM) \$(INCRPM) -o \$@

\$(FROMC): %: %.c
	\$(CC) \$(CCFLAGS) \$(OPTIMIZE) -DVERSION_STRING=\\"\$(RPMTOOLSVERSION)\\" $ccflags \$< \$(LIBRPM) \$(INCRPM) -o \$@

buildc: \$(FROMC) \$(FROMCC)

cleanc:
	rm -f \$(FROMC) \$(FROMCC)
	rm -rf *.cz test

ChangeLog:
	LC_ALL=C svn2cl --accum --strip-prefix=soft/rpm/rpmtools/trunk 
	rm -f *.bak

MAKEMAKEFILE
}

WriteMakefile(
    NAME	    => 'rpmtools',
    VERSION	    => $rpmtools_version,
    macro => {
        RPMTOOLSVERSION => $rpmtools_version,
        FROMC => 'parsehdlist rpm2header #rpm-find-leaves',
        FROMCC => '#gendepslist2 hdlist2names hdlist2files hdlist2prereq hdlist2groups',
        LIBRPM => '-lrpm -lrpmio -lrpmdb -lrpmbuild -lz -lbz2 -lpopt',
        INCRPM => '-I/usr/include/rpm',
    },
    depend => {
        clean_subdirs => 'cleanc',
        pm_to_blib => 'buildc',
    },
    PM => {
        'packdrake.pm' => '$(INST_LIBDIR)/packdrake.pm',
    },
    EXE_FILES	    => [ qw(gendistrib genhdlist genhdlist2 packdrake rpm2header parsehdlist rpm2cpio.pl dumpdistribconf) ],
    C		    => [],
    OBJECT	    => '',
    CCFLAGS	    => '-Wall',
    OPTIMIZE	    => '-O3 -fomit-frame-pointer -fno-exceptions -pipe -s -ffast-math -fexpensive-optimizations',
    INC		    => '',
    LIBS	    => [ '' ],
    INSTALLDIRS	    => 'vendor',
    MAN1PODS	    => {
	dumpdistribconf	=> '$(INST_MAN1DIR)/dumpdistribconf.1',
	gendistrib	=> '$(INST_MAN1DIR)/gendistrib.1',
	genhdlist	=> '$(INST_MAN1DIR)/genhdlist.1',
	genhdlist2	=> '$(INST_MAN1DIR)/genhdlist2.1',
	packdrake	=> '$(INST_MAN1DIR)/packdrake.1',
    },
    MAN3PODS	    => {},
    dist	    => {
        COMPRESS => 'bzip2 --best',
        SUFFIX => '.bz2',
    },
);
