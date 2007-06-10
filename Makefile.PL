# $Id$

use strict;
use ExtUtils::MakeMaker;

my $rpmtools_version = "5.2.0";

# to generate the ChangeLog depending on the checkout layout
my $commonusername = "../common/";
-d $commonusername or do {
    $commonusername = "../../common/";
    -d $commonusername or do {
	$commonusername = "../../../common/";
	-d $commonusername or $commonusername = "";
    };
};

sub MY::postamble {
    <<MAKEMAKEFILE;
.PHONY: ChangeLog

\$(FROMCC): %: %.cc
	\$(CXX) \$(CCFLAGS) \$(OPTIMIZE) -DVERSION_STRING=\\"\$(RPMTOOLSVERSION)\\" \$< \$(LIBRPM) \$(INCRPM) -o \$@

\$(FROMC): %: %.c
	\$(CC) \$(CCFLAGS) \$(OPTIMIZE) -DVERSION_STRING=\\"\$(RPMTOOLSVERSION)\\" \$< \$(LIBRPM) \$(INCRPM) -o \$@

buildc: \$(FROMC) \$(FROMCC)

cleanc:
	rm -f \$(FROMC) \$(FROMCC)
	rm -rf *.cz test

ChangeLog:
	LC_ALL=C svn2cl --accum --strip-prefix=soft/rpm/rpmtools/trunk --authors ${commonusername}username.xml
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
    EXE_FILES	    => [ qw(gendistrib genhdlist packdrake rpm2header parsehdlist rpm2cpio.pl dumpdistribconf) ],
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
	packdrake	=> '$(INST_MAN1DIR)/packdrake.1',
    },
    MAN3PODS	    => {},
    dist	    => {
        COMPRESS => 'bzip2 --best',
        SUFFIX => '.bz2',
    },
);
