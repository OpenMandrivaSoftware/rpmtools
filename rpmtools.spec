%define name rpmtools
%define release 1mdk

# do not modify here, see Makefile in the CVS
%define version 5.0.7

%define group %(perl -e 'printf "%%s\\n", "%_vendor" =~ /mandrake/i ? "System/Configuration/Packaging" : "System Environment/Base"')
%define rpm_version %(rpm -q --queryformat '%{VERSION}-%{RELEASE}' rpm)

Summary: Contains various rpm command-line tools
Name: %{name}
Version: %{version}
Release: %{release}
# get the source from our cvs repository (see
# http://www.linuxmandrake.com/en/cvs.php3)
Source0: %{name}-%{version}.tar.bz2
License: GPL
Group: %{group}
URL: http://cvs.mandrakesoft.com/cgi-bin/cvsweb.cgi/soft/rpmtools
BuildRoot: %{_tmppath}/%{name}-buildroot
Prefix: %{_prefix}
BuildRequires: rpm-devel >= 4.0.3 bzip2-devel
BuildRequires: perl-devel
Requires: rpm >= %{rpm_version} bzip2 >= 1.0 perl-URPM >= 0.94 perl-base >= 5.8.4
Conflicts: rpmtools-compat <= 2.0 rpmtools-devel <= 2.0

%description
Various tools needed by urpmi and drakxtools for handling rpm files.

%package -n packdrake
Group: %{group}
Summary: A simple Archive Extractor/Builder
Conflicts: rpmtools <= 5.0.0
Provides: perl(packdrake)
# perl-Compress-Zlib is only "suggested"
%define _requires_exceptions perl(Compress::Zlib)

%description -n packdrake
Packdrake is a simple indexed archive builder and extractor using
standard compression methods.

Packadrakeng is a from scratch rewrite of the original packdrake. Its format
is fully compatible with old packdrake.

%prep
%setup -q

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor
%make OPTIMIZE="%optflags"
%make test

%install
%{__rm} -rf %{buildroot}
%makeinstall_std

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root)
%{_bindir}/parsehdlist
%{_bindir}/rpm2header
%{_bindir}/gendistrib
%{_bindir}/genhdlist
%{_bindir}/rpm2cpio.pl

%files -n packdrake
%defattr(-,root,root)
%{_bindir}/packdrake
%{perl_vendorlib}/packdrake.pm
%{perl_vendorlib}/Packdrakeng.pm
%{perl_vendorlib}/Packdrakeng/zlib.pm
%{_mandir}/*/*

%changelog
* Thu Dec 30 2004 Olivier Thauvin <thauvin@aerov.jussieu.fr> 5.0.7-1mdk
- speedup uncompress function

* Fri Dec 17 2004 Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> 5.0.6-1mdk
- Ensure Packdrakeng::zlib loads properly, and is not used if Compress::Zlib
  is not available. Remove Compress::Zlib from BuildRequires
- packdrake: show a warning when an archive can't be found
- more docs

* Tue Dec 14 2004 Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> 5.0.5-1mdk
- Fix the "quiet" option of packdrake (so urpmq and other tools don't produce
  warnings)

* Tue Dec 14 2004 Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> 5.0.4-1mdk
- extract_archive() function in packdrake should do nothing if no file list
  is specified
- drop the requirement of packdrake on Compress::Zlib

* Mon Dec 13 2004 Olivier Thauvin <thauvin@aerov.jussieu.fr> 5.0.3-1mdk
- don't use File::* modules (light for gi)
- conflict rpmtools <= 5.0.0 (split package)

* Mon Dec 13 2004 Olivier Thauvin <thauvin@aerov.jussieu.fr> 5.0.2-1mdk
- add missing Packdrake/zlib.pm

* Mon Dec 13 2004 Olivier Thauvin <thauvin@aerov.jussieu.fr> 5.0.1-1mdk
- split package

* Sun Dec 12 2004 Stefan van der Eijk <stefan@eijk.nu> 5.0.0-3mdk
- BuildRequires

* Thu Dec 09 2004 Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> 5.0.0-2mdk
- Mostly doc fixes

* Mon Dec 06 2004 Olivier Thauvin <thauvin@aerov.jussieu.fr> 5.0.0-1mdk
- 5.0.0
- Packdrakeng, new code

* Thu Sep 02 2004 Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> 4.5-25mdk
- Make rpm tools handle new keywords in hdlists file.

* Wed Aug 18 2004 Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> 4.5-24mdk
- Add rpm2cpio.pl

* Wed Aug 11 2004 Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> 4.5-23mdk
- Don't include internal dependencies of the rpmlib in the parsehdlist output

* Thu Jul 22 2004 Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> 4.5-22mdk
- Updates for the new media layout in cooker

* Mon Jul 05 2004 Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> 4.5-21mdk
- Minor changes

* Fri Apr 23 2004 Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> 4.5-20mdk
- add a --quiet option to packdrake
- rebuild for perl 5.8.4, and add a dependency on perl-base

* Wed Feb 25 2004 Olivier Thauvin <thauvin@aerov.jussieu.fr> 4.5-19mdk
- rebuild for perl 5.8.3

* Fri Jan 16 2004 Olivier Thauvin <thauvin@aerov.jussieu.fr> 4.5-18mdk
- Fix genhdlist without arg

* Fri Jan 16 2004 Olivier Thauvin <thauvin@aerov.jussieu.fr> 4.5-17mdk
- add --dest option to genhdlist
- fix dir parsing (Thx Pascal Terjan)

* Fri Jan 09 2004 Warly <warly@mandrakesoft.com> 4.5-16mdk
- add provides perl(packdrake)

* Mon Jan 05 2004 Olivier Thauvin <thauvin@aerov.jussieu.fr> 4.5-15mdk
- add some options to gendistrib/genhdlist

* Tue Dec  9 2003 François Pons <fpons@mandrakesoft.com> 4.5-14mdk
- added compability with RH 7.3.

* Thu Aug 28 2003 François Pons <fpons@mandrakesoft.com> 4.5-13mdk
- added support for %%{ARCH} in gendistrib.
- removing remaining MD5SUM files when running gendistrib.

* Fri Aug  1 2003 François Pons <fpons@mandrakesoft.com> 4.5-12mdk
- rebuild for new perl (DrakX need it).

* Mon May 12 2003 Guillaume Cottenceau <gc@mandrakesoft.com> 4.5-11mdk
- rebuild for new perl requires/provides

* Tue Apr 29 2003 Frederic Lepied <flepied@mandrakesoft.com> 4.5-10mdk
- added support for rpm 4.2

* Mon Mar 10 2003 François Pons <fpons@mandrakesoft.com> 4.5-9mdk
- add support for noauto: flag in hdlists file.
- made gendistrib perl_checker compliant.
- added url (cvsweb of rpmtools).

* Thu Feb 20 2003 François Pons <fpons@mandrakesoft.com> 4.5-8mdk
- fixed bug 414.

* Fri Dec  6 2002 Pixel <pixel@mandrakesoft.com> 4.5-7mdk
- fix a bug in an error message (as detected by perl_checker)

* Wed Dec  4 2002 Pixel <pixel@mandrakesoft.com> 4.5-6mdk
- packdrake.pm is now perl_checker compliant

* Thu Nov 28 2002 Pixel <pixel@mandrakesoft.com> 4.5-5mdk
- packdrake.pm is now perl_checker compliant

* Tue Nov 26 2002 Pixel <pixel@mandrakesoft.com> 4.5-4mdk
- packdrake.pm is now perl_checker compliant

* Wed Oct 16 2002 François Pons <fpons@mandrakesoft.com> 4.5-3mdk
- fixed bad error message for packdrake.
- fixed gendistrib with multiple directory given.
- changed obsoletes of very old package by conflicts.

* Mon Aug  5 2002 Pixel <pixel@mandrakesoft.com> 4.5-2mdk
- have packdrake.pm in non-arch dependent directory

* Mon Aug  5 2002 Guillaume Cottenceau <gc@mandrakesoft.com> 4.5-1mdk
- add --fileswinfo query to parsehdlist so that we can know more
  informations on the package for which we print the files (needed by
  upcoming rpmdrake supporting searching in files)

* Tue Jul 23 2002 François Pons <fpons@mandrakesoft.com> 4.4-1mdk
- removed rpmtools perl module obsoleted.

* Tue Jul  9 2002 Pixel <pixel@mandrakesoft.com> 4.3-6mdk
- rebuild for perl 5.8.0
- little clean of %%files

* Fri Jun 28 2002 François Pons <fpons@mandrakesoft.com> 4.3-5mdk
- added new test to check requires of all package to distriblint.

* Thu Jun 27 2002 François Pons <fpons@mandrakesoft.com> 4.3-4mdk
- added distriblint (was mdkdischk) now using perl-URPM and
  only ported two tests instead of the initial five (some are
  obsoletes now).

* Tue Jun 18 2002 François Pons <fpons@mandrakesoft.com> 4.3-3mdk
- added genhdlist (from Guillaume Rousse).

* Mon Jun  3 2002 François Pons <fpons@mandrakesoft.com> 4.3-2mdk
- use perl-URPM >= 0.02 (modified interface).

* Fri May 31 2002 François Pons <fpons@mandrakesoft.com> 4.3-1mdk
- gendistrib use now perl-URPM.
- keep compatibility with older rpmtools.

* Wed May 29 2002 François Pons <fpons@mandrakesoft.com> 4.2-13mdk
- incorporated fix from URPM module.
- problably latest stable rpmtools release.

* Mon Apr 22 2002 François Pons <fpons@mandrakesoft.com> 4.2-12mdk
- removed "rpmlib(" from synthesis file.

* Mon Apr 15 2002 François Pons <fpons@mandrakesoft.com> 4.2-11mdk
- fixed lock using packdrake --extract when current working
  directory is on NIS and inaccessible (for root).

* Wed Apr 10 2002 François Pons <fpons@mandrakesoft.com> 4.2-10mdk
- make .pm file compatible with perl 5.005 and above (instead of
  perl 5.6.0 and above).

* Wed Mar 20 2002 Frederic Lepied <flepied@mandrakesoft.com> 4.2-9mdk
- rebuild for rpm 4.0.4

* Wed Mar  6 2002 François Pons <fpons@mandrakesoft.com> 4.2-8mdk
- partial fix, now choices are really sorted in depslist.ordered.

* Wed Mar  6 2002 François Pons <fpons@mandrakesoft.com> 4.2-7mdk
- was sure choices in depslist.ordered was sorted, this was not
  the case, but not for the final, it will be.

* Wed Feb 27 2002 François Pons <fpons@mandrakesoft.com> 4.2-6mdk
- removed explicit requires on perl-base (done by spec helper).
- rpmtools.xs code cleaning.

* Tue Feb 19 2002 Stefan van der Eijk <stefan@eijk.nu> 4.2-5mdk
- BuildRequires

* Mon Feb 18 2002 François Pons <fpons@mandrakesoft.com> 4.2-4mdk
- added --silent (undocumented) to parsehdlist.

* Thu Feb 14 2002 François Pons <fpons@mandrakesoft.com> 4.2-3mdk
- fixed rpmtools::_parse_ for memory leak.

* Mon Feb 11 2002 François Pons <fpons@mandrakesoft.com> 4.2-2mdk
- missing fixing arch determination for _parse_ (now correctly
  handles src architecture).

* Fri Feb  8 2002 François Pons <fpons@mandrakesoft.com> 4.2-1mdk
- fixed --descriptions and --summary of parsehdlist for multiline
  output by adding prefix after each linefeed.
- fixed management of source package.

* Tue Feb  5 2002 François Pons <fpons@mandrakesoft.com> 4.1-4mdk
- added possible fixes for using build_hdlist in specific
  environment.

* Wed Jan 30 2002 François Pons <fpons@mandrakesoft.com> 4.1-3mdk
- make sure msec is installed before chkconfig for most
  packages except modutils and initscripts (in order to be
  dependancy safe).
- make sure locales-* are installed very early to avoid warnings.

* Thu Jan 24 2002 François Pons <fpons@mandrakesoft.com> 4.1-2mdk
- fixed wrong _parse_ or rpm file.

* Tue Jan 22 2002 François Pons <fpons@mandrakesoft.com> 4.1-1mdk
- added write_synthesis_hdlist function to handle synthesis file.
- gendistrib now build good synthesis file in Mandrake/base
  directory.

* Thu Jan 17 2002 François Pons <fpons@mandrakesoft.com> 4.0-7mdk
- added safe guard delay to ensure data is available.
- updated parsehdlist with such above feature.

* Thu Jan 17 2002 François Pons <fpons@mandrakesoft.com> 4.0-6mdk
- modified delay management in respect to rpmlib, use
  select to wait for input before giving up to rpmlib.

* Wed Jan 16 2002 François Pons <fpons@mandrakesoft.com> 4.0-5mdk
- added little delay when reading hdlist.

* Tue Jan 15 2002 François Pons <fpons@mandrakesoft.com> 4.0-4mdk
- added --synthesis flag to parsehdlist.

* Thu Jan 10 2002 François Pons <fpons@mandrakesoft.com> 4.0-3mdk
- fixed stupid bug when parsing hdlist.

* Wed Jan  9 2002 François Pons <fpons@mandrakesoft.com> 4.0-2mdk
- slightly modified code to dump hdlist (avoid 1 tempory process).
- improved warning display of gendistrib.

* Wed Dec  5 2001 François Pons <fpons@mandrakesoft.com> 4.0-1mdk
- improved provides management but breaks older urpmi.

* Wed Dec  5 2001 François Pons <fpons@mandrakesoft.com> 3.2-1mdk
- added --info to parsehdlist, needed for brand new urpmi.

* Mon Nov 26 2001 François Pons <fpons@mandrakesoft.com> 3.1-9mdk
- fixed bad rpm2header error analysis (especially under alpha).

* Mon Nov 26 2001 François Pons <fpons@mandrakesoft.com> 3.1-8mdk
- fixed compss file reading.

* Fri Nov 16 2001 François Pons <fpons@mandrakesoft.com> 3.1-7mdk
- fixed problem with depslist generation from synthesis source only.

* Fri Nov 16 2001 François Pons <fpons@mandrakesoft.com> 3.1-6mdk
- fixed bad generation of hdlist for non standard rpm filename.

* Wed Nov 14 2001 François Pons <fpons@mandrakesoft.com> 3.1-5mdk
- changed --name behaviour for newer urpmi.

* Thu Sep 20 2001 François Pons <fpons@mandrakesoft.com> 3.1-4mdk
- build release.

* Thu Aug  9 2001 Pixel <pixel@mandrakesoft.com> 3.1-3mdk
- rebuild for new rpm.

* Wed Jul 25 2001 François Pons <fpons@mandrakesoft.com> 3.1-2mdk
- use rpmvercmp for version_compare.

* Mon Jul 23 2001 François Pons <fpons@mandrakesoft.com> 3.1-1mdk
- allow provides on full package name.
- fixed multiple version, release or arch of the same
  package in the same hdlist.

* Sat Jul 21 2001 Warly <warly@mandrakesoft.com> 3.0-10mdk
- add sourcerpm tag.

* Wed Jul 18 2001 François Pons <fpons@mandrakesoft.com> 3.0-9mdk
- changed rpm requires by including release with test.
- allow bootstrap with current version and not installed one.
- build release for new rpm.

* Thu Jul  5 2001 François Pons <fpons@mandrakesoft.com> 3.0-8mdk
- added compute_id function.

* Mon Jul  2 2001 François Pons <fpons@mandrakesoft.com> 3.0-7mdk
- added arch check support for parsehdlist.

* Thu Jun 28 2001 François Pons <fpons@mandrakesoft.com> 3.0-6mdk
- removed some specific urpm code to urpm package.
- removed obsoleted methods.

* Wed Jun 27 2001 François Pons <fpons@mandrakesoft.com> 3.0-5mdk
- fix problem interpreting serial.

* Wed Jun 27 2001 François Pons <fpons@mandrakesoft.com> 3.0-4mdk
- take care of epoch (serial) for version comparison.

* Tue Jun 26 2001 François Pons <fpons@mandrakesoft.com> 3.0-3mdk
- improved arch management and relocation code.
- fix bad arch parsing when building hdlist.
- fix bad evalution of bad rpm filename.

* Mon Jun 25 2001 François Pons <fpons@mandrakesoft.com> 3.0-2mdk
- fixed version_compare to match rpm behaviour on some cases,
  needed for Garbage Collector cases.
- fixed use of : by @ in provides file.

* Thu Jun 21 2001 François Pons <fpons@mandrakesoft.com> 3.0-1mdk
- changed depslist format to fix support multi-arch.
- changed depslist format to add serial support.
- changed hdlist format to add non standard rpm filename.
- added support to build rpmtools with various rpm.
- added serial, size, summary and description tags.

* Wed Jun 13 2001 François Pons <fpons@mandrakesoft.com> 2.3-25mdk
- really fix with newer rpm (rpmtools.so was missing).
- update distribution tag.

* Wed Jun 13 2001 François Pons <fpons@mandrakesoft.com> 2.3-24mdk
- fix with newer rpm (added -lrpmdb).

* Wed Jun  6 2001 François Pons <fpons@mandrakesoft.com> 2.3-23mdk
- added require on perl-base version used for build.
- fix ordering package to choose libXXX before XXX.

* Tue May 22 2001 François Pons <fpons@mandrakesoft.com> 2.3-22mdk
- added arch support.

* Mon Apr 16 2001 François Pons <fpons@mandrakesoft.com> 2.3-21mdk
- added back anti-lock patch.

* Sat Apr 14 2001 François Pons <fpons@mandrakesoft.com> 2.3-20mdk
- fixed wrong version comparison.

* Sat Apr 14 2001 François Pons <fpons@mandrakesoft.com> 2.3-19mdk
- fixed parsehdlist to print what is needed in synthesis file
  of hdlists.

* Thu Apr 12 2001 François Pons <fpons@mandrakesoft.com> 2.3-18mdk
- added quiet support for packdrake module (for DrakX).

* Tue Apr  3 2001 François Pons <fpons@mandrakesoft.com> 2.3-17mdk
- fixed error code management for parsehdlist.
- fixed read_hdlists return value.

* Mon Mar 26 2001 François Pons <fpons@mandrakesoft.com> 2.3-16mdk
- modified libtermcap to libtermcap2 for VIP.

* Mon Mar 26 2001 François Pons <fpons@mandrakesoft.com> 2.3-15mdk
- fixed depslist sort algorithm to fix Aurora problems.

* Fri Mar 23 2001 François Pons <fpons@mandrakesoft.com> 2.3-14mdk
- reverted rpmtools.xs modification.
- simplified cleaner (include support for sense flag).

* Fri Mar 23 2001 François Pons <fpons@mandrakesoft.com> 2.3-13mdk
- semi-fixed hashes subscript error (workaround).
- added --compact option to parsehdlist.

* Mon Mar 12 2001 François Pons <fpons@mandrakesoft.com> 2.3-12mdk
- added support for LD_LOADER in packdrake module and
  parsehdlist executable.
- removed explicit requires of db2 and db3.
- added BuildRequires for db[123]-devel and libbzip2-devel.

* Fri Mar 09 2001 Francis Galiegue <fg@mandrakesoft.com> 2.3-11mdk
- BuildRequires: perl-devel db2-devel

* Thu Mar  8 2001 François Pons <fpons@mandrakesoft.com> 2.3-10mdk
- fixed duplicate choices in depslist.ordered file.
- fixed missing choices on some deps.

* Wed Mar  7 2001 François Pons <fpons@mandrakesoft.com> 2.3-9mdk
- make sure parsehdlist exit correctly.

* Mon Mar  5 2001 François Pons <fpons@mandrakesoft.com> 2.3-8mdk
- added requires on db2 and db3.

* Thu Mar  1 2001 François Pons <fpons@mandrakesoft.com> 2.3-7mdk
- added compression ratio to build_hdlist.

* Tue Feb 27 2001 François Pons <fpons@mandrakesoft.com> 2.3-6mdk
- fixed gendistrib with multi source of same number as
  media listed in hdlists file.

* Mon Feb 26 2001 François Pons <fpons@mandrakesoft.com> 2.3-5mdk
- improved base flag usage so obsoleted use_base_flag.

* Mon Feb 19 2001 François Pons <fpons@mandrakesoft.com> 2.3-4mdk
- _parse_ returns now fullname of package read.

* Mon Feb 19 2001 François Pons <fpons@mandrakesoft.com> 2.3-3mdk
- fixed version_compare to return number.
- fixed relocate_depslist for package with source to keep.

* Fri Feb 16 2001 François Pons <fpons@mandrakesoft.com> 2.3-2mdk
- fixed invocation of parsehdlist with full package name
  including version and release. make sure to write only one
  description if using the full description.

* Wed Feb 14 2001 François Pons <fpons@mandrakesoft.com> 2.3-1mdk
- changed db_traverse_name to more generic db_traverse_tag
  with support of name, whatprovides, whatrequires, triggeredby,
  group and path.
- added conffiles tag.
- rpmtools.pm to 2.3 to match package version.

* Sat Feb 10 2001 François Pons <fpons@mandrakesoft.com> 2.2-1mdk
- added faster method to access rpm db to rpmtools.xs
  as in DrakX.
- rpmtools.pm to 0.04.

* Tue Jan 30 2001 François Pons <fpons@mandrakesoft.com> 2.1-10mdk
- fixed bug of NOTFOUND_6 in depslist computation.
- fixed depslist relocation bug.

* Tue Jan 23 2001 François Pons <fpons@mandrakesoft.com> 2.1-9mdk
- packdrake.pm to 0.03, added source directory for building an archive.
- changed build_archive to use a specific directory.
- removed bug of gendistrib with relative pathname of distrib.

* Wed Jan 17 2001 François Pons <fpons@mandrakesoft.com> 2.1-8mdk
- removed obsoleted genhdlists, genhdlist_cz2, genbasefiles by gendistrib.
- new tools gendistrib which integrate all the obsoleted tools.
- fixed volative cwd in rpmtools.pm when building hdlist, added noclean support.

* Tue Jan 16 2001 François Pons <fpons@mandrakesoft.com> 2.1-7mdk
- fixed white char in packdrake archive.
- added output mode for parsehdlist.
- added build_hdlist to rpmtools.
- rpmtools.pm to 0.03.

* Fri Jan 05 2001 François Pons <fpons@mandrakesoft.com> 2.1-6mdk
- fixed dependancy in parsehdlist against packdrake.
- fixed packdrake.pm against DrakX usage.

* Fri Dec 08 2000 François Pons <fpons@mandrakesoft.com> 2.1-5mdk
- split packdrake into packdrake.pm, updated version to 0.02.
- rpmtools.pm to 0.02 too.
- added man pages.

* Thu Nov 23 2000 François Pons <fpons@mandrakesoft.com> 2.1-4mdk
- fixed deadlock with version_compare().
- fixed memory leaks in parsehdlist.

* Mon Nov 20 2000 François Pons <fpons@mandrakesoft.com> 2.1-3mdk
- removed ugly log in stdout in parsehdlist.

* Mon Nov 20 2000 François Pons <fpons@mandrakesoft.com> 2.1-2mdk
- fixed abusive -ldb2 and -ldb1 in Makefile.
- fixed deadlock with DrakX by using fflush.
- fixed big bug on execvl (thanks to francis).

* Mon Nov 20 2000 François Pons <fpons@mandrakesoft.com> 2.1-1mdk
- removed rpmtools-compat which is now obsoleted.
- obsoleted genfilelist is removed from rpmtools-devel package.
- removed rpmtools-devel which will be obsoleted by merge on genhdlist*.
- add more complete parsehdlist tools, to be used by DrakX
  in interactive mode.

* Thu Nov 16 2000 François Pons <fpons@mandrakesoft.com> 2.0-6mdk
- updated order of 9 first package to be installed.
- removed memory consuming code in perl.

* Tue Nov  7 2000 Pixel <pixel@mandrakesoft.com> 2.0-5mdk
- add requires for -devel

* Tue Nov  7 2000 Pixel <pixel@mandrakesoft.com> 2.0-4mdk
- fix compability spelling error

* Tue Nov  7 2000 Pixel <pixel@mandrakesoft.com> 2.0-3mdk
- capitalize summaries

* Thu Oct 19 2000 François Pons <fpons@mandrakesoft.com> 2.0-2mdk
- fixed speed problem of rpmtools depslist computation, now 10x faster!

* Thu Oct 19 2000 Frederic Lepied <flepied@mandrakesoft.com> 2.0-1mdk
- updated for rpm 4.

* Fri Sep 15 2000 Pixel <pixel@mandrakesoft.com> 1.2-11mdk
- genhdlist_cz2, packdrake, build_archive: use TMPDIR if exists

* Mon Sep 04 2000 François Pons <fpons@mandrakesoft.com> 1.2-10mdk
- fixed management of basesystem, so that it always keeps all
  its dependancies in order to keep ability to update base packages
  when dobles on basesystem exists.

* Sun Sep 03 2000 François Pons <fpons@mandrakesoft.com> 1.2-9mdk
- fixed write_depslist to avoid resorting, fixes dobles.
- fixed compute_depslist to use only remove dobles in provides.
- fixed genbasefiles to do 3 pass instead of 2, because provides is no more
  used in such a case.
- moved version_compare in rpmtools perl package.
- added relocation of packages to match the best ones (so that urpmi install
  the most up-to-date version it finds).

* Fri Sep 01 2000 François Pons <fpons@mandrakesoft.com> 1.2-8mdk
- fixed read_provides with unresolved dependancies.

* Tue Aug 29 2000 François Pons <fpons@mandrakesoft.com> 1.2-7mdk
- fixed rpmtools.pm depslist.ordered reading code on gendepslist2 produced
  file.

* Tue Aug 29 2000 François Pons <fpons@mandrakesoft.com> 1.2-6mdk
- fixed hdlist2groups with wrong invocations of parsehdlist.

* Mon Aug 28 2000 François Pons <fpons@mandrakesoft.com> 1.2-5mdk
- fixed packdrake to not use absolute pathname by default for uncompression
  method, else this breaks DrakX as software are not in same place.

* Mon Aug 28 2000 François Pons <fpons@mandrakesoft.com> 1.2-4mdk
- moved genbasefiles to rpmtools as it is used by urpmi.

* Mon Aug 28 2000 François Pons <fpons@mandrakesoft.com> 1.2-3mdk
- fixed ugly arch specific optimization in Makefile.PL.

* Fri Aug 25 2000 François Pons <fpons@mandrakesoft.com> 1.2-2mdk
- added rpmtools perl module.
- added genbasefiles to build compss, depslist.ordered and provides files
  in one (or two) pass.

* Wed Aug 23 2000 François Pons <fpons@mandrakesoft.com> 1.2-1mdk
- 1.2 of rpmtools.
- new tools packdrake and parsehdlist.

* Mon Aug 07 2000 Frederic Lepied <flepied@mandrakesoft.com> 1.1-30mdk
- automatically added BuildRequires

* Thu Aug  3 2000 Pixel <pixel@mandrakesoft.com> 1.1-29mdk
- skip "rpmlib(..." dependencies

* Thu Jul 27 2000 Pixel <pixel@mandrakesoft.com> 1.1-28mdk
- fix handling of choices in basesystem (hdlist -1)

* Wed Jul 12 2000 Pixel <pixel@mandrakesoft.com> 1.1-27mdk
- add version require for last bzip2 and last rpm

* Tue Jun 13 2000 Pixel <pixel@mandrakesoft.com> 1.1-25mdk
- fix a bug in gendepslist2 (thanks to diablero)

* Thu Jun 08 2000 François Pons <fpons@mandrakesoft.com> 1.1-24mdk
- fixed bug in genhdlist_cz2 for multi arch management.

* Thu May 25 2000 François Pons <fpons@mandrakesoft.com> 1.1-23mdk
- adding multi arch management (sparc and sparc64 need).

* Tue May 02 2000 François Pons <fpons@mandrakesoft.com> 1.1-22mdk
- fixed bug for extracting file if some of them are unknown.

* Fri Apr 28 2000 Pixel <pixel@mandrakesoft.com> 1.1-21mdk
- more robust gendepslist2

* Thu Apr 20 2000 François Pons <fpons@mandrakesoft.com> 1.1-20mdk
- dropped use strict in some perl script, for rescue.

* Wed Apr 19 2000 François Pons <fpons@mandrakesoft.com> 1.1-19mdk
- rewrite description.

* Wed Apr 19 2000 François Pons <fpons@mandrakesoft.com> 1.1-18mdk
- update with CVS.

* Fri Apr 14 2000 Pixel <pixel@mandrakesoft.com> 1.1-17mdk
- fix buggy extract_archive

* Fri Apr 14 2000 Pixel <pixel@mandrakesoft.com> 1.1-16mdk
- updated genhdlists

* Fri Mar 31 2000 François PONS <fpons@mandrakesoft.com> 1.1-15mdk
- add genfilelist

* Tue Mar 28 2000 Pixel <pixel@mandrakesoft.com> 1.1-14mdk
- fix silly bug

* Mon Mar 27 2000 Pixel <pixel@mandrakesoft.com> 1.1-13mdk
- add hdlist2groups

* Sun Mar 26 2000 Pixel <pixel@mandrakesoft.com> 1.1-12mdk
- gendepslist2: add ability to handle files (was only hdlist.cz2's), and to
output only the package dependencies for some hdlist's/packages (use of "--")

* Sat Mar 25 2000 Pixel <pixel@mandrakesoft.com> 1.1-11mdk
- new group

* Fri Mar 24 2000 Pixel <pixel@mandrakesoft.com> 1.1-10mdk
- gendepslist2 bug fix again

* Thu Mar 23 2000 Pixel <pixel@mandrakesoft.com> 1.1-9mdk
- gendepslist2 now put filesystem and setup first

* Thu Mar 23 2000 Pixel <pixel@mandrakesoft.com> 1.1-8mdk
- gendepslist2 now handles virtual basesystem requires

* Wed Mar 22 2000 Pixel <pixel@mandrakesoft.com> 1.1-7mdk
- add require rpm >= 3.0.4
- gendepslist2 now puts basesystem first in depslist.ordered
- gendepslist2 orders better 

* Mon Mar 20 2000 Pixel <pixel@mandrakesoft.com> 1.1-5mdk
- fix a bug in gendepslist2 (in case of choices)

* Tue Mar  7 2000 Pixel <pixel@mandrakesoft.com> 1.1-1mdk
- new version (gendepslist2 instead of gendepslist, hdlist2prereq)
- host build_archive/extract_archive until francois put them somewhere else :)

* Fri Feb 18 2000 Chmouel Boudjnah <chmouel@mandrakesoft.com> 1.0-9mdk
- Really fix with rpm-3.0.4 (Fredl).

* Thu Feb 17 2000 Chmouel Boudjnah <chmouel@mandrakesoft.com> 1.0-8mdk
- rpmtools.spec (BuildRequires): rpm-3.0.4.
- gendepslist.cc: port to rpm-3.0.4.
- Makefile: cvs support, add -lpopt.

* Tue Jan  4 2000 Pixel <pixel@mandrakesoft.com>
- renamed hdlist2files in hdlist2names
- added hdlist2files

* Sun Dec 19 1999 Pixel <pixel@mandrakesoft.com>
- added ability to read from stdin to hdlist2files

* Sat Dec 18 1999 Pixel <pixel@mandrakesoft.com>
- modified gendepslist to accept hdlist's from stdin

* Thu Nov 25 1999 Pixel <pixel@linux-mandrake.com>
- removed rpm-find-leaves (now in urpmi)

* Sun Nov 21 1999 Pixel <pixel@mandrakesoft.com>
- now installed in /usr/bin
- added rpm-find-leaves
- replaced -lrpm by %{_libdir}/librpm.so.0 to make it dynamic
(why is this needed?)

* Mon Nov 15 1999 Pixel <pixel@mandrakesoft.com>

- first version


# end of file
