%define name rpmtools
%define release 1mdk

# do not modify here, see Makefile in the CVS
%define version 1.1

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
BuildRequires: rpm-devel >= 3.0.4
Requires: /usr/bin/perl

%description
Various rpmtools.

%package devel
Summary: contains various rpm command-line tools for development
Group: Development/System
%description devel
Various devel rpm tools.

%prep
%setup

%build
make

%install
make install PREFIX=$RPM_BUILD_ROOT

%clean
rm -rf $RPM_BUILD_ROOT
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/usr/bin/gendepslist2
/usr/bin/hdlist2files
/usr/bin/hdlist2names
/usr/bin/rpm2header
/usr/bin/genhdlist_cz2

%files devel
%defattr(-,root,root)
/usr/bin/hdlist2prereq

%changelog
* Tue Mar  7 2000 Pixel <pixel@mandrakesoft.com> 1.1-1mdk
- new version (gendepslist2 instead of gendepslist, hdlist2prereq)

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
