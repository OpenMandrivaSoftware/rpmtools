#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
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
static char print_sep = 0;

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

/*
static
void print_list(Header header, int_32 tag_name, char *format, char sep, char *name) {
  int_32 type, count;
  char **list;
  int i;

  headerGetEntry(header, tag_name, &type, (void **) &list, &count);

  if (list) {
    for(i = 0; i < count; i++) {
      if (sep && i > 0) printf("%c%s", sep, list[i]);
      else printf(format, name, list[i]);
      if (!sep) printf("\n");
    }
    if (sep) printf("\n");
  }
  free(list);
}
*/

static
void print_list_flags(Header header, int_32 tag_name, int_32 tag_flags, int_32 tag_version, char *format, char sep, char *name) {
  int_32 type, count;
  char **list;
  int_32 *flags;
  char **list_evr;
  int i;

  headerGetEntry(header, tag_name, &type, (void **) &list, &count);
  headerGetEntry(header, tag_flags, &type, (void **) &flags, &count);
  headerGetEntry(header, tag_version, &type, (void **) &list_evr, &count);

  if (list) {
    for(i = 0; i < count; i++) {
      if (sep && i > 0) printf("%c%s", sep, list[i]);
      else printf(format, name, list[i]);
      if (list_evr[i] && list_evr[i][0]) {
	printf(" ");
	if (flags[i] & RPMSENSE_LESS) printf("<");
	if (flags[i] & RPMSENSE_GREATER) printf(">");
	if (flags[i] & RPMSENSE_EQUAL) printf("=");
	if ((flags[i] & (RPMSENSE_LESS|RPMSENSE_EQUAL|RPMSENSE_GREATER)) == RPMSENSE_EQUAL) printf("=");
	printf(" %s", list_evr[i]);
      }
      if (!sep) printf("\n");
    }
    if (sep) printf("\n");
  }
  free(list);
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
  free(list);
}

static
void print_list_files(Header header, char *format, char *name) {
  int_32 type, count;
  char **list;
  char ** baseNames, ** dirNames;
  int_32 * dirIndexes;
  int i;

  headerGetEntry(header, RPMTAG_OLDFILENAMES, &type, (void **) &list, &count);

  if (list)
    for (i = 0; i < count; i++) printf(format, name, list[i]);
  free(list);

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
  free(baseNames);
  free(dirNames);
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
	  "  --compact       - print compact provides, requires, conflicts, obsoletes flags.\n"
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

void
print_header_flag_interactive(char *in_tag, Header header)
{
  if (!strncmp(in_tag, "provides", 8)) print_list_flags(header, RPMTAG_PROVIDENAME, RPMTAG_PROVIDEFLAGS,
							     RPMTAG_PROVIDEVERSION, "%2$s", 0, "");
  else if (!strncmp(in_tag, "requires", 8)) print_list_flags(header, RPMTAG_REQUIRENAME, RPMTAG_REQUIREFLAGS,
							     RPMTAG_REQUIREVERSION, "%2$s", 0, "");
  else if (!strncmp(in_tag, "conflicts", 9)) print_list_flags(header, RPMTAG_CONFLICTNAME, RPMTAG_CONFLICTFLAGS,
							      RPMTAG_CONFLICTVERSION, "%2$s", 0, "");
  else if (!strncmp(in_tag, "obsoletes", 9)) print_list_flags(header, RPMTAG_OBSOLETENAME, RPMTAG_OBSOLETEFLAGS,
							      RPMTAG_OBSOLETEVERSION,"%2$s", 0, "");
  else if (!strncmp(in_tag, "files", 5)) print_list_files(header, "%2$s\n", "");
  else if (!strncmp(in_tag, "prereqs", 7)) print_list_prereqs(header, "%2$s\n", "");
  else if (!strncmp(in_tag, "group", 5)) printf("%s\n", get_name(header, RPMTAG_GROUP));
  else if (!strncmp(in_tag, "name", 4)) printf("%s-%s-%s.%s.rpm\n", 
					       get_name(header, RPMTAG_NAME),
					       get_name(header, RPMTAG_VERSION),
					       get_name(header, RPMTAG_RELEASE),
					       get_name(header, RPMTAG_ARCH));
}

char *
printable_header(int quiet, char *name, char sep, char* final)
{
  static char buff[128];
  int n = sprintf(buff, "%%s%c", sep ? sep : ':');
  if (!quiet) n += sprintf(buff + n, "%s%c", name, sep ? sep : ':');
  n += sprintf(buff + n, "%%s");
  if (final) n += sprintf(buff + n, "%s", final);
  return buff; /* static string, this means to use result before calling again */
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
      else if (strcmp(argv[i], "--compact") == 0)     print_sep = '@';
      else if (strcmp(argv[i], "--name") == 0)        print_name = 1;
      else if (strcmp(argv[i], "--group") == 0)       print_group = 1;
      else if (strcmp(argv[i], "--provides") == 0)    print_provides = 1;
      else if (strcmp(argv[i], "--requires") == 0)    print_requires = 1;
      else if (strcmp(argv[i], "--files") == 0)       print_files = 1;
      else if (strcmp(argv[i], "--conflicts") == 0)   print_conflicts = 1;
      else if (strcmp(argv[i], "--obsoletes") == 0)   print_obsoletes = 1;
      else if (strcmp(argv[i], "--prereqs") == 0)     print_prereqs = 1;
      else if (strcmp(argv[i], "--output") == 0) {
	if (i+1 >= argc || !argv[i+1] || !argv[i+1][0]) {
	  fprintf(stderr, "option --output need a valid filename after it\n");
	  exit(1);
	}
	if (!freopen(argv[i+1], "w", stdout)) {
	  unlink(argv[i+1]);
	  fprintf(stderr, "unable to redirect output to [%s]\n", argv[i+1]);
	  exit(1);
	} else ++i; /* avoid parsing filename as an argument */
      } else if (strcmp(argv[i], "--all") == 0) {
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
	    int fda, fdn;
	    struct {
	      char header[4];
	      char toc_d_count[4];
	      char toc_l_count[4];
	      char toc_f_count[4];
	      char toc_str_size[4];
	      char uncompress[40];
	      char trailer[4];
	    } buf;
	    char *unpacker[22]; /* enough for 40 bytes above to never overbuf */
	    char *p = buf.uncompress;
	    int ip = 0;
	    char *ld_loader = getenv("LD_LOADER");

	    if (ld_loader && *ld_loader) {
	      unpacker[ip++] = ld_loader;
	    }

	    dup2(fdno[1], STDOUT_FILENO); close(fdno[1]);
	    fda = open(argv[i], O_RDONLY);
	    if (fda < 0) { perror("parsehdlist"); exit(1); }
	    lseek(fda, -sizeof(buf), SEEK_END);
	    if (read(fda, &buf, sizeof(buf)) != sizeof(buf) ||
		strncmp(buf.header, "cz[0", 4) ||
		strncmp(buf.trailer, "0]cz", 4)) {
	      fprintf(stderr, "parsehdlist: invalid archive %s\n", argv[i]);
	      exit(1);
	    }
	    buf.trailer[0] = 0; /* make sure end-of-string is right */
	    while (*p) {
	      if (*p == ' ' || *p == '\t') *p++ = 0;
	      else {
		unpacker[ip++] = p;
		while (*p && *p != ' ' && *p != '\t') ++p;
	      }
	    }
	    unpacker[ip] = NULL; /* needed for execlp */

	    lseek(fda, 0, SEEK_SET);
	    dup2(fda, STDIN_FILENO); close(fda);
	    fdn = open("/dev/null", O_WRONLY);
	    dup2(fdn, STDERR_FILENO); close(fdn);
	    execvp(unpacker[0], unpacker);
	    exit(2);
	  }
	} else {
	  fprintf(stderr, "packdrake: unable to create pipe for packdrake\n");
	}
      }
      if (fdFileno(fd) < 0) {
	fprintf(stderr, "parsehdlist: cannot open file %s\n", argv[i]);
	exit(1);
      } else  {
	Header header;
	long count = 0;

	/* fprintf(stderr, "parsehdlist: reading %s\n", argv[i]); */
	while ((header=headerRead(fd, HEADER_MAGIC_YES))) {
	  char *name = get_name(header, RPMTAG_NAME);

	  ++count;
	  if (interactive_mode) {
	    headers[count_headers].name = name;
	    headers[count_headers].hash_name = hash(name);
	    headers[count_headers].header = header;

	    ++count_headers;
	  } else {
	    if (print_provides) print_list_flags(header, RPMTAG_PROVIDENAME, RPMTAG_PROVIDEFLAGS, RPMTAG_PROVIDEVERSION,
						 printable_header(print_quiet, "provides", print_sep, 0), print_sep, name);
	    if (print_requires) print_list_flags(header, RPMTAG_REQUIRENAME, RPMTAG_REQUIREFLAGS, RPMTAG_REQUIREVERSION,
						 printable_header(print_quiet, "requires", print_sep, 0), print_sep, name);
	    if (print_conflicts) print_list_flags(header, RPMTAG_CONFLICTNAME, RPMTAG_CONFLICTFLAGS, RPMTAG_CONFLICTVERSION,
						  printable_header(print_quiet, "conflicts", print_sep, 0), print_sep, name);
	    if (print_obsoletes) print_list_flags(header, RPMTAG_OBSOLETENAME, RPMTAG_OBSOLETEFLAGS, RPMTAG_OBSOLETEVERSION,
						  printable_header(print_quiet, "obsoletes", print_sep, 0), print_sep, name);
	    if (print_files) print_list_files(header, printable_header(print_quiet, "files", print_sep, "\n"), name);
	    if (print_prereqs) print_list_prereqs(header, printable_header(print_quiet, "prereqs", print_sep, "\n"), name);
	    if (print_group) printf(printable_header(print_quiet, "group", print_sep, "\n"), name, get_name(header, RPMTAG_GROUP));
	    if (print_name || (print_provides | print_requires | print_files | print_conflicts | print_obsoletes | print_prereqs |
			       print_group) == 0) {
	      if (print_name) printf(printable_header(print_quiet, "name", print_sep, 0), name);
	      printf("%s-%s-%s.%s.rpm\n", 
		     name,
		     get_name(header, RPMTAG_VERSION),
		     get_name(header, RPMTAG_RELEASE),
		     get_name(header, RPMTAG_ARCH));
	    }
	    headerFree(header);
	  }
	}
	if (!count) exit(3); /* no package is an error */
      }
      fdClose(fd);
      if (pid) {
	waitpid(pid, NULL, 0);
	pid = 0;
      }
    }
  }

  /* interactive mode */
  while (interactive_mode) {
    char in_name[4096];
    char *in_tag, *in_version, *in_release;
    unsigned long hash_in_name;
    int i, count = 0;

    if (!fgets(in_name, sizeof(in_name), stdin) || *in_name == '\n' || !*in_name) break;
    if ((in_tag = strchr(in_name, ':')) == NULL) {
      fprintf(stderr, "invalid command, should be name:tag\n");
      break;
    }
    *in_tag++ = 0;
    if ((in_release = strrchr(in_name, '-')) != NULL) {
      *in_release++ = 0;
      if ((in_version = strrchr(in_name, '-')) != NULL) {
	*in_version++ = 0;
	hash_in_name = hash(in_name);
	for (i = 0; i < count_headers; ++i) {
	  if (headers[i].hash_name == hash_in_name && !strcmp(headers[i].name, in_name)) {
	    if (strcmp(get_name(headers[i].header, RPMTAG_VERSION), in_version)) continue;
	    if (strcmp(get_name(headers[i].header, RPMTAG_RELEASE), in_release)) continue;
	    print_header_flag_interactive(in_tag, headers[i].header);
	    ++count;
	    break; /* special case to avoid multiple output for multiply defined same package */
	  }
	}
	if (!count) in_version[-1] = '-';
      }
      if (!count) {
	in_version = in_release;
	hash_in_name = hash(in_name);
	for (i = 0; i < count_headers; ++i) {
	  if (headers[i].hash_name == hash_in_name && !strcmp(headers[i].name, in_name)) {
	    if (strcmp(get_name(headers[i].header, RPMTAG_VERSION), in_version)) continue;
	    print_header_flag_interactive(in_tag, headers[i].header);
	    ++count;
	  }
	}
	if (!count) in_version[-1] = '-';
      }
    }
    if (!count) {
      hash_in_name = hash(in_name);
      for (i = 0; i < count_headers; ++i) {
	if (headers[i].hash_name == hash_in_name && !strcmp(headers[i].name, in_name)) {
	  print_header_flag_interactive(in_tag, headers[i].header);
	  ++count;
	}
      }
    }
    /* if (!count) {
       fprintf(stderr, "no package found matching the description: %s!\n", in_name);
       } */
    printf("\n");
    fflush(stdout);
  }

  return 0;
}
