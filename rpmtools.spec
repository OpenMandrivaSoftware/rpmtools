%define name rpmtools
%define version 1.0
%define release 9mdk

Summary: contains various rpm command-line tools
Name: %{name}
Version: %{version}
Release: %{release}
# get the source from our cvs repository (see
# http://www.linuxmandrake.com/en/cvs.php3)
Source0: %{name}-%{version}.tar.bz2
Copyright: GPL
Group: System Environment/Base
BuildRoot: %{_tmppath}/%{name}-buildroot
Prefix: %{_prefix}
BuildRequires: rpm-devel >= 3.0.4

%description
Various rpmtools.

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
/usr/bin/*


%changelog
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
