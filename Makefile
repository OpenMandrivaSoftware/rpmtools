VERSION = 1.1
NAME = rpmtools
FROMC = rpm2header #rpm-find-leaves
FROMCC = gendepslist2 hdlist2names hdlist2files hdlist2prereq
ALL = $(FROMC) $(FROMCC)
CFLAGS = -Wall -g
LIBRPM = /usr/lib/librpm.so.0 -ldb1 -lz -I/usr/include/rpm -lpopt

all: $(ALL)

install: $(ALL)
	install -d $(PREFIX)/usr/bin
	install -s $(ALL) genhdlist_cz2 build_archive extract_archive $(PREFIX)/usr/bin

$(FROMCC): %: %.cc 
	$(CXX) $(CFLAGS) $< $(LIBRPM) -o $@

$(FROMC): %: %.c
	$(CC) $(CFLAGS) $< $(LIBRPM) -o $@

clean: 
	rm -rf *~ $(ALL)

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