%define name rpmtools
%define release 5mdk

# do not modify here, see Makefile in the CVS
%define version 2.1

Summary: Contains various rpm command-line tools
Name: %{name}
Version: %{version}
Release: %{release}
# get the source from our cvs repository (see
# http://www.linuxmandrake.com/en/cvs.php3)
Source0: %{name}-%{version}.tar.bz2
License: GPL
Group: System/Configuration/Packaging
BuildRoot: %{_tmppath}/%{name}-buildroot
Prefix: %{_prefix}
BuildRequires: rpm-devel >= 4.0 bzip2 popt-devel zlib-devel
Requires: /usr/bin/perl rpm >= 4.0 bzip2 >= 1.0
Obsoletes: rpmtools-compat <= 2.0 rpmtools-devel <= 2.0

%description
Various tools needed by urpmi and drakxtools for handling rpm files.

%prep
%setup

%build
%{__perl} Makefile.PL
%{make} -f Makefile_core OPTIMIZE="$RPM_OPT_FLAGS"
%{make} CFLAGS="$RPM_OPT_FLAGS"

%install
rm -rf $RPM_BUILD_ROOT
%{make} install PREFIX=$RPM_BUILD_ROOT
%{make} -f Makefile_core install PREFIX=$RPM_BUILD_ROOT%{_prefix}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%{_bindir}/packdrake
%{_bindir}/parsehdlist
%{_bindir}/rpm2header
%{_bindir}/genhdlists
%{_bindir}/genhdlist_cz2
%{_bindir}/genbasefiles
%dir %{perl_sitearch}/auto/rpmtools
%{perl_sitearch}/auto/rpmtools/rpmtools.so
%{perl_sitearch}/packdrake.pm
%{perl_sitearch}/rpmtools.pm
%{_libdir}/perl5/man/*/*

%changelog
* Fri Dec 08 2000 Fran�ois Pons <fpons@mandrakesoft.com> 2.1-5mdk
- split packdrake into packdrake.pm, updated version to 0.02.
- rpmtools.pm to 0.02 too.
- added man pages.

* Thu Nov 23 2000 Fran�ois Pons <fpons@mandrakesoft.com> 2.1-4mdk
- fixed deadlock with version_compare().
- fixed memory leaks in parsehdlist.

* Mon Nov 20 2000 Fran�ois Pons <fpons@mandrakesoft.com> 2.1-3mdk
- removed ugly log in stdout in parsehdlist.

* Mon Nov 20 2000 Fran�ois Pons <fpons@mandrakesoft.com> 2.1-2mdk
- fixed abusive -ldb2 and -ldb1 in Makefile.
- fixed deadlock with DrakX by using fflush.
- fixed big bug on execvl (thanks to francis).

* Mon Nov 20 2000 Fran�ois Pons <fpons@mandrakesoft.com> 2.1-1mdk
- removed rpmtools-compat which is now obsoleted.
- obsoleted genfilelist is removed from rpmtools-devel package.
- removed rpmtools-devel which will be obsoleted by merge on genhdlist*.
- add more complete parsehdlist tools, to be used by DrakX
  in interactive mode.

* Thu Nov 16 2000 Fran�ois Pons <fpons@mandrakesoft.com> 2.0-6mdk
- updated order of 9 first package to be installed.
- removed memory consuming code in perl.

* Tue Nov  7 2000 Pixel <pixel@mandrakesoft.com> 2.0-5mdk
- add requires for -devel

* Tue Nov  7 2000 Pixel <pixel@mandrakesoft.com> 2.0-4mdk
- fix compability spelling error

* Tue Nov  7 2000 Pixel <pixel@mandrakesoft.com> 2.0-3mdk
- capitalize summaries

* Thu Oct 19 2000 Fran�ois Pons <fpons@mandrakesoft.com> 2.0-2mdk
- fixed speed problem of rpmtools depslist computation, now 10x faster!

* Thu Oct 19 2000 Frederic Lepied <flepied@mandrakesoft.com> 2.0-1mdk
- updated for rpm 4.

* Fri Sep 15 2000 Pixel <pixel@mandrakesoft.com> 1.2-11mdk
- genhdlist_cz2, packdrake, build_archive: use TMPDIR if exists

* Mon Sep 04 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.2-10mdk
- fixed management of basesystem, so that it always keeps all
  its dependancies in order to keep ability to update base packages
  when dobles on basesystem exists.

* Sun Sep 03 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.2-9mdk
- fixed write_depslist to avoid resorting, fixes dobles.
- fixed compute_depslist to use only remove dobles in provides.
- fixed genbasefiles to do 3 pass instead of 2, because provides is no more
  used in such a case.
- moved version_compare in rpmtools perl package.
- added relocation of packages to match the best ones (so that urpmi install
  the most up-to-date version it finds).

* Fri Sep 01 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.2-8mdk
- fixed read_provides with unresolved dependancies.

* Tue Aug 29 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.2-7mdk
- fixed rpmtools.pm depslist.ordered reading code on gendepslist2 produced
  file.

* Tue Aug 29 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.2-6mdk
- fixed hdlist2groups with wrong invocations of parsehdlist.

* Mon Aug 28 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.2-5mdk
- fixed packdrake to not use absolute pathname by default for uncompression
  method, else this breaks DrakX as software are not in same place.

* Mon Aug 28 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.2-4mdk
- moved genbasefiles to rpmtools as it is used by urpmi.

* Mon Aug 28 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.2-3mdk
- fixed ugly arch specific optimization in Makefile.PL.

* Fri Aug 25 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.2-2mdk
- added rpmtools perl module.
- added genbasefiles to build compss, depslist.ordered and provides files
  in one (or two) pass.

* Wed Aug 23 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.2-1mdk
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

* Thu Jun 08 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.1-24mdk
- fixed bug in genhdlist_cz2 for multi arch management.

* Thu May 25 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.1-23mdk
- adding multi arch management (sparc and sparc64 need).

* Tue May 02 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.1-22mdk
- fixed bug for extracting file if some of them are unknown.

* Fri Apr 28 2000 Pixel <pixel@mandrakesoft.com> 1.1-21mdk
- more robust gendepslist2

* Thu Apr 20 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.1-20mdk
- dropped use strict in some perl script, for rescue.

* Wed Apr 19 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.1-19mdk
- rewrite description.

* Wed Apr 19 2000 Fran�ois Pons <fpons@mandrakesoft.com> 1.1-18mdk
- update with CVS.

* Fri Apr 14 2000 Pixel <pixel@mandrakesoft.com> 1.1-17mdk
- fix buggy extract_archive

* Fri Apr 14 2000 Pixel <pixel@mandrakesoft.com> 1.1-16mdk
- updated genhdlists

* Fri Mar 31 2000 Fran�ois PONS <fpons@mandrakesoft.com> 1.1-15mdk
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
- replaced -lrpm by /usr/lib/librpm.so.0 to make it dynamic
(why is this needed?)

* Mon Nov 15 1999 Pixel <pixel@mandrakesoft.com>

- first version


# end of file
