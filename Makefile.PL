# $Id$

# use 5.008;
use ExtUtils::MakeMaker;
use MDK::Common qw(cat_);

(my $rpmtools_version) = cat_('rpmtools.spec') =~ /define\s+version\s+(\d+\.\d+\.\d+)/
    or die "no version found\n";


my $tag_version = "v$rpmtools_version";
$tag_version =~ s/\./_/g;

sub MY::postamble {
    <<MAKEMAKEFILE;
.PHONY: ChangeLog

\$(FROMCC): %: %.cc
	\$(CXX) \$(CCFLAGS) \$(OPTIMIZE) -DVERSION_STRING=\\"\$(RPMTOOLSVERSION)\\" \$< \$(LIBRPM) \$(INCRPM) \$(DEFRPM) -o \$@

\$(FROMC): %: %.c
	\$(CC) \$(CCFLAGS) \$(OPTIMIZE) -DVERSION_STRING=\\"\$(RPMTOOLSVERSION)\\" \$< \$(LIBRPM) \$(INCRPM) \$(DEFRPM) -o \$@

buildc: \$(FROMC) \$(FROMCC)

cleanc:
	rm -f \$(FROMC) \$(FROMCC)
	rm -rf *.cz test

ChangeLog:
	cvs2cl -W 400 -I ChangeLog --accum -U ../common/username
	rm -f *.bak

rpm: dist
	rpm --define "_sourcedir `pwd`" -ba --clean --rmsource rpmtools.spec

tag:
	cvs tag $tag_version


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
        DEFRPM => '-DRPM_42',
    },
    depend => {
        clean_subdirs => 'cleanc',
        pm_to_blib => 'buildc',
    },
    PM => {
        'Packdrakeng.pm' => '$(INST_LIBDIR)/Packdrakeng.pm',
        'Packdrakeng/zlib.pm' => '$(INST_LIBDIR)/Packdrakeng/zlib.pm',
        'packdrake.pm' => '$(INST_LIBDIR)/packdrake.pm',
        'Distribconf.pm' => '$(INST_LIBDIR)/Distribconf.pm',
    },
    'EXE_FILES' => [ qw(gendistrib genhdlist packdrake rpm2header parsehdlist rpm2cpio.pl dumpdistribconf) ],
    C => [],
    'OBJECT'        => '',
    CCFLAGS	    => '-Wall',
    OPTIMIZE	    => '-O3 -fomit-frame-pointer -fno-exceptions -pipe -s -ffast-math -fexpensive-optimizations',
    INC		    => '',
    LIBS	    => [ '' ],
    INSTALLDIRS	    => 'vendor',
    dist    => {
        COMPRESS => 'bzip2 --best',
        SUFFIX => '.bz2',
    },
);
