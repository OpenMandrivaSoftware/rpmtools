#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <rpm/rpmlib.h>
#include <rpm/header.h>
#include <iostream>


char *get_name(Header header, int_32 tag) {
  int_32 type, count;
  char *name;

  headerGetEntry(header, tag, &type, (void **) &name, &count);
  return name;
}

int get_int(Header header, int_32 tag) {
  int_32 type, count;
  int *i;

  headerGetEntry(header, tag, &type, (void **) &i, &count);
  return *i;
}

int main(int argc, char **argv) 
{
  if (argc <= 1) {
    cerr << "usage: hdlist2groups <hdlist> [<hdlists...>]\n";
    exit(1);
  }
  for (int i = 1; i < argc; i++) {
    FD_t fd = strcmp(argv[i], "-") == 0 ? fdDup(STDIN_FILENO) : fdOpen(argv[i], O_RDONLY, 0);
    if (fdFileno(fd) < 0) cerr << "hdlist2groups: cannot open file " << argv[i] << "\n";
    else  {
      Header header;
      while ((header=headerRead(fd, HEADER_MAGIC_YES))) {
	printf("%s:%s\n", 
	       get_name(header, RPMTAG_NAME),
	       get_name(header, RPMTAG_GROUP));
      }
    }
    fdClose(fd);
  }
}