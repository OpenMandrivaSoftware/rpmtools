FROMC = rpm2header #rpm-find-leaves
FROMCC = gendepslist hdlist2names hdlist2files
ALL = $(FROMC) $(FROMCC)
LIBRPM = /usr/lib/librpm.so.0 -ldb1 -lz -I/usr/include/rpm -lpopt

all: $(ALL)

install: $(ALL)
	install -d $(PREFIX)/usr/bin
	install -s $(ALL) $(PREFIX)/usr/bin

$(FROMCC): %: %.cc 
	$(CXX) $(CFLAGS) $< $(LIBRPM) -o $@

$(FROMC): %: %.c
	$(CC) $(CFLAGS) $< $(LIBRPM) -o $@

clean: 
	rm -rf *~ $(ALL)
