# $Id$

use strict;
use ExtUtils::MakeMaker;

my $rpmtools_version = "5.9";

# where to find the rpm utility

sub MY::postamble {
    <<MAKEMAKEFILE;
.PHONY: ChangeLog

cleanc:
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
    },
    depend => {
        clean_subdirs => 'cleanc',
    },
    PM => {
        'packdrake.pm' => '$(INST_LIBDIR)/packdrake.pm',
    },
    EXE_FILES	    => [ qw(gendistrib genhdlist-old genhdlist2 packdrake dumpdistribconf) ],
    C		    => [],
    OBJECT	    => '',
    CCFLAGS	    => '-Wall',
    INC		    => '',
    LIBS	    => [ '' ],
    INSTALLDIRS	    => 'vendor',
    MAN1PODS	    => {
	dumpdistribconf	=> '$(INST_MAN1DIR)/dumpdistribconf.1',
	gendistrib	=> '$(INST_MAN1DIR)/gendistrib.1',
	'genhdlist-old'	=> '$(INST_MAN1DIR)/genhdlist-old.1',
	genhdlist2	=> '$(INST_MAN1DIR)/genhdlist2.1',
	packdrake	=> '$(INST_MAN1DIR)/packdrake.1',
    },
    MAN3PODS	    => {},
    dist	    => {
        COMPRESS => 'bzip2 --best',
        SUFFIX => '.bz2',
    },
);
