VERSION = 1.1
NAME = rpmtools
FROMC = rpm2header #rpm-find-leaves
FROMCC = gendepslist2 hdlist2names hdlist2files hdlist2prereq hdlist2groups
FROMC_STATIC  = $(FROMC:%=%_static)
FROMCC_STATIC = $(FROMCC:%=%_static)
ALL = $(FROMC) $(FROMCC)
ALL_STATIC = $(FROMC_STATIC) $(FROMCC_STATIC)
CFLAGS = -Wall -g
LIBRPM = -lrpm -ldb1 -lz -lbz2 -I/usr/include/rpm -lpopt

all: $(ALL)

install: $(ALL)
	install -d $(PREFIX)/usr/bin
	install -s $(ALL) $(PREFIX)/usr/bin
	install genhdlist_cz2 genhdlists build_archive extract_archive $(PREFIX)/usr/bin

$(FROMCC): %: %.cc 
	$(CXX) $(CFLAGS) $< $(LIBRPM) -o $@

$(FROMCC_STATIC): %_static: %.cc 
	$(CXX) -s -static $(CFLAGS) $< $(LIBRPM) -o $@

$(FROMC): %: %.c
	$(CC) $(CFLAGS) $< $(LIBRPM) -o $@

$(FROMC_STATIC): %_static: %.c
	$(CC) -s -static $(CFLAGS) $< $(LIBRPM) -o $@

clean: 
	rm -rf *~ $(ALL) $(ALL_STATIC)

dis: clean
	rm -rf $(NAME)-$(VERSION) ../$(NAME)-$(VERSION).tar*
	mkdir -p $(NAME)-$(VERSION)
	find . -not -name "$(NAME)-$(VERSION)"|cpio -pd $(NAME)-$(VERSION)/
	find $(NAME)-$(VERSION) -type d -name CVS -o -name .cvsignore -o -name unused |xargs rm -rf
	perl -p -i -e 's|^%define version.*|%define version $(VERSION)|' $(NAME).spec
	tar cf ../$(NAME)-$(VERSION).tar $(NAME)-$(VERSION)
	bzip2 -9f ../$(NAME)-$(VERSION).tar
	rm -rf $(NAME)-$(VERSION)

rpm: dis ../$(NAME)-$(VERSION).tar.bz2 $(RPM)
	cp -f ../$(NAME)-$(VERSION).tar.bz2 $(RPM)/SOURCES
	cp -f $(NAME).spec $(RPM)/SPECS/
	-rpm -ba --clean --rmsource $(NAME).spec
	rm -f ../$(NAME)-$(VERSION).tar.bz2
