#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <rpm/rpmlib.h>
#include <rpm/header.h>
#include <stdio.h>
#include <string.h>

#ifndef VERSION_STRING
#define VERSION_STRING "0.0"
#endif

/* static data for very simple list */
static struct {
  char *name;
  unsigned long hash_name;
  Header header;
} headers[16384];
static int count_headers = 0;

static int raw_hdlist = 0;
static int interactive_mode = 0;
static int print_quiet = 0;
static int print_name = 0;
static int print_group = 0;
static int print_provides = 0;
static int print_requires = 0;
static int print_conflicts = 0;
static int print_obsoletes = 0;
static int print_files = 0;
static int print_prereqs = 0;

static
unsigned long hash(char *str) {
  unsigned long result = 0;
  while (*str) {
    result += (result<<5) + (unsigned char)*str++;
  }
  return result;
}

static
char *get_name(Header header, int_32 tag) {
  int_32 type, count;
  char *name;

  headerGetEntry(header, tag, &type, (void **) &name, &count);
  return name;
}

static
void print_list(Header header, int_32 tag_name, char *format, char *name) {
  int_32 type, count;
  char **list;
  int i;

  headerGetEntry(header, tag_name, &type, (void **) &list, &count);

  if (list)
    for(i = 0; i < count; i++)
      printf(format, name, list[i]);
}

static
void print_list_flags(Header header, int_32 tag_name, int_32 tag_flags, int_32 tag_version, char *format, char *name) {
  int_32 type, count;
  char **list;
  int_32 *flags;
  char **list_evr;
  int i;

  headerGetEntry(header, tag_name, &type, (void **) &list, &count);
  headerGetEntry(header, tag_flags, &type, (void **) &flags, &count);
  headerGetEntry(header, tag_version, &type, (void **) &list_evr, &count);

  if (list)
    for(i = 0; i < count; i++) {
      printf(format, name, list[i]);
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

static
void print_list_prereqs(Header header, char *format, char *name) {
  int_32 type, count;
  char **list;
  int_32 *flags;
  int i;

  headerGetEntry(header, RPMTAG_REQUIRENAME, &type, (void **) &list, &count);
  headerGetEntry(header, RPMTAG_REQUIREFLAGS, &type, (void **) &flags, &count);

  if (flags && list)
    for(i = 0; i < count; i++)
      if (flags[i] & RPMSENSE_PREREQ) printf(format, name, list[i]);
}

static
void print_list_files(Header header, char *format, char *name) {
  int_32 type, count;
  char **list;
  char ** baseNames, ** dirNames;
  int_32 * dirIndexes;
  int i;

  headerGetEntry(header, RPMTAG_OLDFILENAMES, &type, (void **) &list, &count);

  if (list) {
    for (i = 0; i < count; i++) printf(format, name, list[i]);
  }

  headerGetEntry(header, RPMTAG_BASENAMES, &type, (void **) &baseNames, &count);
  headerGetEntry(header, RPMTAG_DIRINDEXES, &type, (void **) &dirIndexes, NULL);
  headerGetEntry(header, RPMTAG_DIRNAMES, &type, (void **) &dirNames, NULL);

  if (baseNames && dirNames && dirIndexes) {
    char buff[4096];
    for(i = 0; i < count; i++) {
      sprintf(buff, "%s%s", dirNames[dirIndexes[i]], baseNames[i]);
      printf(format, name, buff);
    }
  }
}

static
void print_help(void) {
  fprintf(stderr,
	  "parsehdlist version " VERSION_STRING "\n"
	  "Copyright (C) 2000 MandrakeSoft.\n"
	  "This is free software and may be redistributed under the terms of the GNU GPL.\n"
	  "\n"
	  "usage:\n"
	  "  --help          - print this help message.\n"
	  "  --raw           - assume raw hdlist (always the case for -).\n"
	  "  --interactive   - interactive mode (following options are taken from stdin\n"
	  "                    and output only the necessary data, end as emtpy line, not\n"
	  "                    compatible with any print tag commands).\n"
	  "  --quiet         - do not print tag name (default if no tag given on command\n"
	  "                    line, incompatible with interactive mode).\n"
	  "  --all           - print all tags (incompatible with interactive mode).\n"
	  "  --name          - print tag name: rpm filename (assumed if no tag given on\n"
	  "                    command line but without package name).\n"
	  "  --group         - print tag group: group.\n"
	  "  --provides      - print tag provides: all provides (mutliple lines).\n"
	  "  --requires      - print tag requires: all requires (multiple lines).\n"
	  "  --files         - print tag files: all files (multiple lines).\n"
	  "  --conflicts     - print tag conflicts: all conflicts (multiple lines).\n"
	  "  --obsoletes     - print tag obsoletes: all obsoletes (multiple lines).\n"
	  "  --prereqs       - print tag prereqs: all prereqs (multiple lines).\n"
	  "\n");
}

int main(int argc, char **argv) 
{
  int i;

  if (argc <= 1) {
    print_help();
    exit(1);
  }
  for (i = 1; i < argc; i++) {
    if (argv[i][0] == '-' && argv[i][1] == '-') {
      if (strcmp(argv[i], "--help") == 0) {
	print_help();
	exit(0);
      } else if (strcmp(argv[i], "--raw") == 0)       raw_hdlist = 1;
      else if (strcmp(argv[i], "--interactive") == 0) interactive_mode = 1;
      else if (strcmp(argv[i], "--quiet") == 0)       print_quiet = 1;
      else if (strcmp(argv[i], "--name") == 0)        print_name = 1;
      else if (strcmp(argv[i], "--group") == 0)       print_group = 1;
      else if (strcmp(argv[i], "--provides") == 0)    print_provides = 1;
      else if (strcmp(argv[i], "--requires") == 0)    print_requires = 1;
      else if (strcmp(argv[i], "--files") == 0)       print_files = 1;
      else if (strcmp(argv[i], "--conflicts") == 0)   print_conflicts = 1;
      else if (strcmp(argv[i], "--obsoletes") == 0)   print_obsoletes = 1;
      else if (strcmp(argv[i], "--prereqs") == 0)     print_prereqs = 1;
      else if (strcmp(argv[i], "--all") == 0) {
	print_name = 1;
	print_group = 1;
	print_provides = 1;
	print_requires = 1;
	print_files = 1;
	print_conflicts = 1;
	print_obsoletes = 1;
	print_prereqs = 1;
      } else {
	fprintf(stderr, "parsehdlist: unknown option %s\n", argv[i]);
      }
    } else {
      FD_t fd;
      pid_t pid = 0;
      if (strcmp(argv[i], "-") == 0) fd = fdDup(STDIN_FILENO);
      else if (raw_hdlist)           fd = fdOpen(argv[i], O_RDONLY, 0);
      else {
	int fdno[2];
	if (!pipe(fdno)) {
	  if ((pid = fork()) != 0) {
	    fd = fdDup(fdno[0]);
	    close(fdno[0]);
	    close(fdno[1]);
	  } else {
	    dup2(fdno[1], STDOUT_FILENO);
	    execl("/usr/bin/packdrake", "/usr/bin/packdrake", "-c", argv[i]);
	    exit(2);
	  }
	}
      }
      if (fdFileno(fd) < 0) fprintf(stderr, "parsehdlist: cannot open file %s\n", argv[i]);
      else  {
	Header header;

	while ((header=headerRead(fd, HEADER_MAGIC_YES))) {
	  char *name = get_name(header, RPMTAG_NAME);

	  if (interactive_mode) {
	    headers[count_headers].name = name;
	    headers[count_headers].hash_name = hash(name);
	    headers[count_headers].header = header;

	    ++count_headers;
	  } else {
	    if (print_provides) print_list(header, RPMTAG_PROVIDENAME, print_quiet ? "%s:%s\n" : "%s:provides:%s\n", name);
	    if (print_requires) print_list_flags(header, RPMTAG_REQUIRENAME, RPMTAG_REQUIREFLAGS, RPMTAG_REQUIREVERSION,
						 print_quiet ? "%s:%s" : "%s:requires:%s", name);
	    if (print_conflicts) print_list_flags(header, RPMTAG_CONFLICTNAME, RPMTAG_CONFLICTFLAGS, RPMTAG_CONFLICTVERSION,
						  print_quiet ? "%s:%s" : "%s:conflicts:%s", name);
	    if (print_obsoletes) print_list_flags(header, RPMTAG_OBSOLETENAME, RPMTAG_OBSOLETEFLAGS, RPMTAG_OBSOLETEVERSION,
						  print_quiet ? "%s:%s" : "%s:obsoletes:%s", name);
	    if (print_files) print_list_files(header, print_quiet ? "%s:%s\n" : "%s:files:%s\n", name);
	    if (print_prereqs) print_list_prereqs(header, print_quiet ? "%s:%s\n" : "%s:prereqs:%s\n", name);
	    if (print_group) printf(print_quiet ? "%s:%s\n" : "%s:group:%s\n", name, get_name(header, RPMTAG_GROUP));
	    if (print_name || (print_provides | print_requires | print_files | print_conflicts | print_obsoletes | print_prereqs |
			       print_group) == 0) {
	      if (print_name) printf(print_quiet ? "%s:" : "%s:name:", name);
	      printf("%s-%s-%s.%s.rpm\n", 
		     name,
		     get_name(header, RPMTAG_VERSION),
		     get_name(header, RPMTAG_RELEASE),
		     get_name(header, RPMTAG_ARCH));
	    }
	    headerFree(header);
	  }
	}
      }
      fdClose(fd);
      if (pid) {
	waitpid(pid, NULL, 0);
	pid = 0;
      }
    }
  }

  /* interactive mode */
  if (interactive_mode) {
    do {
      char in_name[4096];
      char *in_tag;
      int i;
      unsigned long hash_in_name;

      if (!fgets(in_name, sizeof(in_name), stdin)) break;
      if ((in_tag = strchr(in_name, ':')) == NULL) break;
      *in_tag++ = 0;
      hash_in_name = hash(in_name);
      for (i = 0; i < count_headers; ++i) {
	if (headers[i].hash_name == hash_in_name && !strcmp(headers[i].name, in_name)) {
	  if (!strncmp(in_tag, "provides", 8)) print_list(headers[i].header, RPMTAG_PROVIDENAME, "%2$s\n", "");
	  else if (!strncmp(in_tag, "requires", 8)) print_list_flags(headers[i].header, RPMTAG_REQUIRENAME, RPMTAG_REQUIREFLAGS,
								     RPMTAG_REQUIREVERSION,"%2$s", "");
	  else if (!strncmp(in_tag, "conflicts", 9)) print_list_flags(headers[i].header, RPMTAG_CONFLICTNAME, RPMTAG_CONFLICTFLAGS,
								      RPMTAG_CONFLICTVERSION, "%2$s", "");
	  else if (!strncmp(in_tag, "obsoletes", 9)) print_list_flags(headers[i].header, RPMTAG_OBSOLETENAME, RPMTAG_OBSOLETEFLAGS,
								      RPMTAG_OBSOLETEVERSION,"%2$s", "");
	  else if (!strncmp(in_tag, "files", 5)) print_list_files(headers[i].header, "%2$s\n", "");
	  else if (!strncmp(in_tag, "prereqs", 7)) print_list_prereqs(headers[i].header, "%2$s\n", "");
	  else if (!strncmp(in_tag, "group", 5)) printf("%s\n", get_name(headers[i].header, RPMTAG_GROUP));
	  else if (!strncmp(in_tag, "name", 4)) printf("%s-%s-%s.%s.rpm\n", 
						       get_name(headers[i].header, RPMTAG_NAME),
						       get_name(headers[i].header, RPMTAG_VERSION),
						       get_name(headers[i].header, RPMTAG_RELEASE),
						       get_name(headers[i].header, RPMTAG_ARCH));
	}
      }
      printf("\n");
    } while (1);
  }

  return 0;
}
