#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <rpm/rpmlib.h>
#include <rpm/header.h>
#include <stdio.h>


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
  int print_quiet = 0;
  int print_provides = 0;
  int print_requires = 0;
  int print_conflicts = 0;
  int print_obsoletes = 0;
  int print_files = 0;
  int print_group = 0;
  int print_prereqs = 0;
  int print_name = 0;
  int i;

  if (argc <= 1) {
    fprintf(stderr, "usage: parsehdlist [--quiet|--provides|--requires|--conflicts|--obsoletes|--files|--prereqs|--group|--name|--all] <hdlist> [<hdlists...>]\n");
    exit(1);
  }
  for (i = 1; i < argc; i++) {
    if (argv[i][0] == '-' && argv[i][1] == '-') {
      if (strcmp(argv[i], "--quiet") == 0)          print_quiet = 1;
      else if (strcmp(argv[i], "--provides") == 0)  print_provides = 1;
      else if (strcmp(argv[i], "--requires") == 0)  print_requires = 1;
      else if (strcmp(argv[i], "--files") == 0)     print_files = 1;
      else if (strcmp(argv[i], "--conflicts") == 0) print_conflicts = 1;
      else if (strcmp(argv[i], "--obsoletes") == 0) print_obsoletes = 1;
      else if (strcmp(argv[i], "--prereqs") == 0)   print_prereqs = 1;
      else if (strcmp(argv[i], "--group") == 0)     print_group = 1;
      else if (strcmp(argv[i], "--name") == 0)      print_name = 1;
      else if (strcmp(argv[i], "--all") == 0) {
	print_provides = print_requires = print_files = print_conflicts = print_obsoletes = print_prereqs =
	  print_group = print_name = 1;
      } else {
	fprintf(stderr, "parsehdlist: unknown option %s\n", argv[i]);
      }
    } else {
      FD_t fd = strcmp(argv[i], "-") == 0 ? fdDup(STDIN_FILENO) : fdOpen(argv[i], O_RDONLY, 0);
      if (fdFileno(fd) < 0) fprintf(stderr, "parsehdlist: cannot open file %s\n", argv[i]);
      else  {
	Header header;
	int_32 type, count;
	char **list;
	int_32 *flags;

	while ((header=headerRead(fd, HEADER_MAGIC_YES))) {
	  char *name = get_name(header, RPMTAG_NAME);

	  if (print_provides) {
	    headerGetEntry(header, RPMTAG_PROVIDENAME, &type, (void **) &list, &count);

	    if (list)
	      for(i = 0; i < count; i++)
		printf(print_quiet ? "%s:%s\n" : "%s:provides:%s\n", name, list[i]);
	  }
	  if (print_requires) {
	    char **list_evr;

	    headerGetEntry(header, RPMTAG_REQUIRENAME, &type, (void **) &list, &count);
	    headerGetEntry(header, RPMTAG_REQUIREFLAGS, &type, (void **) &flags, &count);
	    headerGetEntry(header, RPMTAG_REQUIREVERSION, &type, (void **) &list_evr, &count);

	    if (list)
	      for(i = 0; i < count; i++) {
		printf(print_quiet ? "%s:%s" : "%s:requires:%s", name, list[i]);
		if (list_evr[i]) {
		  printf(" ");
		  if (flags[i] & RPMSENSE_LESS) printf("<");
		  if (flags[i] & RPMSENSE_GREATER) printf(">");
		  if (flags[i] & RPMSENSE_EQUAL) printf("=");
		  printf(" %s", list_evr[i]);
		}
		printf("\n");
	      }
	  }
	  if (print_conflicts) {
	    char **list_evr;

	    headerGetEntry(header, RPMTAG_CONFLICTNAME, &type, (void **) &list, &count);
	    headerGetEntry(header, RPMTAG_CONFLICTFLAGS, &type, (void **) &flags, &count);
	    headerGetEntry(header, RPMTAG_CONFLICTVERSION, &type, (void **) &list_evr, &count);

	    if (list)
	      for(i = 0; i < count; i++) {
		printf(print_quiet ? "%s:%s" : "%s:conflicts:%s", name, list[i]);
		if (list_evr[i]) {
		  printf(" ");
		  if (flags[i] & RPMSENSE_LESS) printf("<");
		  if (flags[i] & RPMSENSE_GREATER) printf(">");
		  if (flags[i] & RPMSENSE_EQUAL) printf("=");
		  printf(" %s", list_evr[i]);
		}
		printf("\n");
	      }
	  }
	  if (print_obsoletes) {
	    char **list_evr;

	    headerGetEntry(header, RPMTAG_OBSOLETENAME, &type, (void **) &list, &count);
	    headerGetEntry(header, RPMTAG_OBSOLETEFLAGS, &type, (void **) &flags, &count);
	    headerGetEntry(header, RPMTAG_OBSOLETEVERSION, &type, (void **) &list_evr, &count);

	    if (list)
	      for(i = 0; i < count; i++) {
		printf(print_quiet ? "%s:%s" : "%s:obsoletes:%s", name, list[i]);
		if (list_evr[i]) {
		  printf(" ");
		  if (flags[i] & RPMSENSE_LESS) printf("<");
		  if (flags[i] & RPMSENSE_GREATER) printf(">");
		  if (flags[i] & RPMSENSE_EQUAL) printf("=");
		  printf(" %s", list_evr[i]);
		}
		printf("\n");
	      }
	  }
	  if (print_files) {
	    char ** baseNames, ** dirNames;
	    int_32 * dirIndexes;

	    headerGetEntry(header, RPMTAG_OLDFILENAMES, &type, (void **) &list, &count);

	    if (list) {
	      for (i = 0; i < count; i++) printf(print_quiet ? "%s:%s\n" : "%s:files:%s\n", name, list[i]);
	    }

	    headerGetEntry(header, RPMTAG_BASENAMES, &type, (void **) &baseNames, 
			   &count);
	    headerGetEntry(header, RPMTAG_DIRINDEXES, &type, (void **) &dirIndexes, 
			   NULL);
	    headerGetEntry(header, RPMTAG_DIRNAMES, &type, (void **) &dirNames, NULL);

	    if (baseNames && dirNames && dirIndexes) {
	      for(i = 0; i < count; i++) {
		printf(print_quiet ? "%s:%s%s\n" : "%s:files:%s%s\n", name, dirNames[dirIndexes[i]], baseNames[i]);
	      }
	    }
	  }
	  if (print_prereqs) {
	    headerGetEntry(header, RPMTAG_REQUIRENAME, &type, (void **) &list, &count);
	    headerGetEntry(header, RPMTAG_REQUIREFLAGS, &type, (void **) &flags, &count);

	    if (flags && list)
	      for(i = 0; i < count; i++)
		if (flags[i] & RPMSENSE_PREREQ) printf(print_quiet ? "%s:%s\n" : "%s:prereqs:%s\n", name, list[i]);
	  }
	  if (print_group) {
	    printf(print_quiet ? "%s:%s\n" : "%s:group:%s\n", 
		   name,
		   get_name(header, RPMTAG_GROUP));
	  }
	  if (print_name || (print_provides | print_requires | print_files | print_conflicts | print_obsoletes | print_prereqs |
			     print_group) == 0) {
	    if (print_name) printf(print_quiet ? "%s:" : "%s:name:", name);
	    printf("%s-%s-%s.%s.rpm\n", 
		   name,
		   get_name(header, RPMTAG_VERSION),
		   get_name(header, RPMTAG_RELEASE),
		   get_name(header, RPMTAG_ARCH));
	  }
	}
      }
      fdClose(fd);
    }
  }

  return 0;
}
