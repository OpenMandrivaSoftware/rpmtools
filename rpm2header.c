#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <rpmlib.h>
#if defined(RPM_FORMAT_VERSION) && RPM_FORMAT_VERSION >= 5
#include "rpm5compat.h"
#endif
#include <rpm/rpmts.h>

const char *basename(const char *f) {
    char *p = strrchr(f, '/');
    return p ? p + 1 : f;
}

int_32 FD_size(FD_t fd) {
    struct stat sb;
    fstat(fdFileno(fd), &sb);
    return sb.st_size;
}

int main(int argc, char **argv) {
    int i;
    FD_t fout;

    if (argc < 2) {
	fprintf(stderr, "usage: rpm2header <rpms>\n");
	exit(1);
    }

    fout = fdDup(1 /*stdout*/);

    for (i = 1; i < argc; i++) {
	FD_t fd;
	Header h;
	int_32 size;
	const char *name = basename(argv[i]);
	rpmts ts;

	fprintf(stderr, "%s\n", argv[i]);

	if (!(fd = fdOpen(argv[i], O_RDONLY, 0666))) {
	    perror("open");
	    exit(1);
	}
	size = FD_size(fd);

	ts = rpmtsCreate();
	rpmtsSetVSFlags(ts, _RPMVSF_NOSIGNATURES);
	if (rpmReadPackageFile(ts, fd, argv[1], &h) == 0) {
	    headerRemoveEntry(h, RPMTAG_POSTIN);
	    headerRemoveEntry(h, RPMTAG_POSTUN);
	    headerRemoveEntry(h, RPMTAG_PREIN);
	    headerRemoveEntry(h, RPMTAG_PREUN);
	    headerRemoveEntry(h, RPMTAG_FILEUSERNAME);
	    headerRemoveEntry(h, RPMTAG_FILEGROUPNAME);
	    headerRemoveEntry(h, RPMTAG_FILEVERIFYFLAGS);
	    headerRemoveEntry(h, RPMTAG_FILERDEVS);
	    headerRemoveEntry(h, RPMTAG_FILEMTIMES);
	    headerRemoveEntry(h, RPMTAG_FILEDEVICES);
	    headerRemoveEntry(h, RPMTAG_FILEINODES);
	    headerRemoveEntry(h, RPMTAG_TRIGGERSCRIPTS);
	    headerRemoveEntry(h, RPMTAG_TRIGGERVERSION);
	    headerRemoveEntry(h, RPMTAG_TRIGGERFLAGS);
	    headerRemoveEntry(h, RPMTAG_TRIGGERNAME);
	    headerRemoveEntry(h, RPMTAG_CHANGELOGTIME);
	    headerRemoveEntry(h, RPMTAG_CHANGELOGNAME);
	    headerRemoveEntry(h, RPMTAG_CHANGELOGTEXT);
	    headerRemoveEntry(h, RPMTAG_ICON);
	    headerRemoveEntry(h, RPMTAG_GIF);
	    headerRemoveEntry(h, RPMTAG_VENDOR);
	    headerRemoveEntry(h, RPMTAG_EXCLUDE);
	    headerRemoveEntry(h, RPMTAG_EXCLUSIVE);
	    headerRemoveEntry(h, RPMTAG_DISTRIBUTION);
	    headerRemoveEntry(h, RPMTAG_VERIFYSCRIPT);
	    headerWrite(fout, h, HEADER_MAGIC_YES);
	    headerFree(h);
	}
	fdClose(fd);
    }
    return 0;
}
