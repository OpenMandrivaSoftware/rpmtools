%define name rpmtools
%define release 4mdk

# do not modify here, see Makefile in the CVS
%define version 1.2

Summary: contains various rpm command-line tools
Name: %{name}
Version: %{version}
Release: %{release}
# get the source from our cvs repository (see
# http://www.linuxmandrake.com/en/cvs.php3)
Source0: %{name}-%{version}.tar.bz2
Copyright: GPL
Group: System/Configuration/Packaging
BuildRoot: %{_tmppath}/%{name}-buildroot
Prefix: %{_prefix}
BuildRequires: rpm-devel >= 3.0.5-0.20mdk bzip2 popt-devel zlib-devel
Requires: /usr/bin/perl rpm >= 3.0.5-0.20mdk bzip2 >= 1.0

%description
Various tools needed by urpmi and drakxtools for handling rpm files.

%package devel
Summary: contains various rpm command-line tools for development
Group: Development/Other
%description devel
Various devel rpm tools which can be used to build a customized
Linux-Mandrake distribution.

%package compat
Summary: contains various rpm command-line tools for compability
Group: System/Configuration/Packaging
Requires: rpmtools
%description compat
Various rpm tools for compability issue with previous version of
rpmtools package.

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

# compability tools, based upon parsehdlist ones.
ln -s parsehdlist $RPM_BUILD_ROOT%{_bindir}/hdlist2names

cat <<EOF >$RPM_BUILD_ROOT%{_bindir}/hdlist2prereq
#!/bin/sh
%{_bindir}/parsehdlist --quiet --prereqs $*
EOF
chmod a+x $RPM_BUILD_ROOT%{_bindir}/hdlist2prereq

cat <<EOF >$RPM_BUILD_ROOT%{_bindir}/hdlist2groups
#!/bin/sh
%{_bindir}/parsehdlist --quiet --groups $*
EOF
chmod a+x $RPM_BUILD_ROOT%{_bindir}/hdlist2groups

cat <<EOF >$RPM_BUILD_ROOT%{_bindir}/hdlist2files
#!/bin/sh
%{_bindir}/parsehdlist --quiet --files $*
EOF
chmod a+x $RPM_BUILD_ROOT%{_bindir}/hdlist2files

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%{_bindir}/packdrake
%{_bindir}/parsehdlist
%{_bindir}/rpm2header
%{_bindir}/genhdlist_cz2
%{_bindir}/genbasefiles
%dir %{perl_sitearch}/auto/rpmtools
%{perl_sitearch}/auto/rpmtools/rpmtools.so
%{perl_sitearch}/rpmtools.pm

%files devel
%defattr(-,root,root)
%{_bindir}/genhdlists
%{_bindir}/genfilelist

%files compat
%defattr(-,root,root)
%{_bindir}/gendepslist2
%{_bindir}/hdlist2prereq
%{_bindir}/hdlist2groups
%{_bindir}/hdlist2files
%{_bindir}/hdlist2names


%changelog
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
- replaced -lrpm by /usr/lib/librpm.so.0 to make it dynamic
(why is this needed?)

* Mon Nov 15 1999 Pixel <pixel@mandrakesoft.com>

- first version


# end of file
