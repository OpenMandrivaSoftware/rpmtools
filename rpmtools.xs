#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#undef Fflush
#undef Mkdir
#undef Stat
#include <rpm/rpmlib.h>
#include <rpm/header.h>

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

HV* get_info(Header header) {
  HV* info = newHV();
  char *name = get_name(header, RPMTAG_NAME);
  STRLEN len = strlen(name);

  if (info != 0) {
    SV* sv_name = newSVpv(name, len);
    SV* sv_version = newSVpv(get_name(header, RPMTAG_VERSION), 0);
    SV* sv_release = newSVpv(get_name(header, RPMTAG_RELEASE), 0);

    hv_store(info, "name", 4, sv_name, 0);
    hv_store(info, "version", 7, sv_version, 0);
    hv_store(info, "release", 7, sv_release, 0);
  }

  return info;
}

SV *get_table_sense(Header header, int_32 tag_name, int_32 tag_flags, int_32 tag_version, HV* iprovides) {
  AV* table_sense;
  int_32 type, count;
  char **list;
  int_32 *flags;
  char **list_evr;
  int i;

  char buff[4096];
  char *p;
  int len;

  headerGetEntry(header, tag_name, &type, (void **) &list, &count);
  if (tag_flags) headerGetEntry(header, tag_flags, &type, (void **) &flags, &count);
  else flags = 0;
  if (tag_version) headerGetEntry(header, tag_version, &type, (void **) &list_evr, &count);
  else list_evr = 0;

  if (list) {
    table_sense = newAV();
    if (!table_sense) return &PL_sv_undef;

    for(i = 0; i < count; i++) {
      len = strlen(list[i]); if (len >= sizeof(buff)) continue;
      memcpy(p = buff, list[i], len + 1); p+= len;

      if (flags) {
	if (flags[i] & RPMSENSE_PREREQ) {
	  if (p - buff + 3 >= sizeof(buff)) continue;
	  memcpy(p, "[*]", 4); p += 3;
	}
	if (list_evr) {
	  if (list_evr[i]) {
	    len = strlen(list_evr[i]);
	    if (len > 0) {
	      if (p - buff + 6 + len >= sizeof(buff)) continue;
	      *p++ = '[';
	      if (flags[i] & RPMSENSE_LESS) *p++ = '<';
	      if (flags[i] & RPMSENSE_GREATER) *p++ = '>';
	      if (flags[i] & RPMSENSE_EQUAL) *p++ = '=';
	      if ((flags[i] & (RPMSENSE_LESS|RPMSENSE_EQUAL|RPMSENSE_GREATER)) == RPMSENSE_EQUAL) *p++ = '=';
	      *p++ = ' ';
	      memcpy(p, list_evr[i], len); p+= len;
	      *p++ = ']';
	      *p = '\0';
	    }
	  }
	}
      }

      /* for getting provides about required files */
      if (iprovides && buff[0] == '/')
	hv_fetch(iprovides, buff, p - buff, 1);

      av_push(table_sense, newSVpv(buff, p - buff));
    }

    return newRV_noinc((SV*)table_sense);
  }
  return &PL_sv_undef;
}

#define HDFLAGS_NAME          0x00000001
#define HDFLAGS_VERSION       0x00000002
#define HDFLAGS_RELEASE       0x00000004
#define HDFLAGS_ARCH          0x00000008
#define HDFLAGS_GROUP         0x00000010
#define HDFLAGS_SIZE          0x00000020
#define HDFLAGS_SENSE         0x00080000
#define HDFLAGS_REQUIRES      0x00100000
#define HDFLAGS_PROVIDES      0x00200000
#define HDFLAGS_OBSOLETES     0x00400000
#define HDFLAGS_CONFLICTS     0x00800000
#define HDFLAGS_FILES         0x01000000
#define HDFLAGS_DIRSIND       0x02000000
#define HDFLAGS_FILESIND      0x04000000


MODULE = rpmtools			PACKAGE = rpmtools


int
get_packages_installed(prefix, packages, lnames)
  char* prefix
  SV* packages
  SV* lnames
  PREINIT:
  int count = 0;
  CODE:
  if (SvROK(packages) && SvTYPE(SvRV(packages)) == SVt_PVAV &&
      SvROK(lnames) && SvTYPE(SvRV(lnames)) == SVt_PVAV) {
    AV* pkgs = (AV*)SvRV(packages);
    AV* names = (AV*)SvRV(lnames);
    HV* info;
    SV** isv;
    rpmdb db;
    dbiIndexSet matches;
    int num, i, j, rc, len;
    char *name;
    Header header;
    
    if (rpmReadConfigFiles(NULL, NULL) == 0) {
      if (rpmdbOpen(prefix, &db, O_RDONLY, 0644) == 0) {
	len = av_len(names);
	for (j = 0; j <= len; ++j) {
	  isv = av_fetch(names, j, 0);
	  name = SvPV_nolen(*isv);
	  rc = rpmdbFindPackage(db, name, &matches);
	  if (rc == 0) {
	    count += matches.count;
	    for (i = 0; i < matches.count; ++i) {
	      header = rpmdbGetRecord(db, matches.recs[i].recOffset);
	      info = get_info(header);

	      if (info != 0) av_push(pkgs, newRV_noinc((SV*)info));

	      headerFree(header);
	    }
	  }
	}
	rpmdbClose(db);
      } else croak("unable to open database");
    } else croak("cannot read rpm config files");
  } else croak("bad arguments list");
  RETVAL = count;
  OUTPUT:
  RETVAL


int
get_all_packages_installed(prefix, packages)
  char* prefix
  SV* packages
  PREINIT:
  int count = 0;
  CODE:
  if (SvROK(packages) && SvTYPE(SvRV(packages)) == SVt_PVAV) {
    AV* pkgs = (AV*)SvRV(packages);
    HV* info;
    rpmdb db;
    int num;
    Header header;
    
    if (rpmReadConfigFiles(NULL, NULL) == 0) {
      if (rpmdbOpen(prefix, &db, O_RDONLY, 0644) == 0) {
	num = rpmdbFirstRecNum(db);
	while (num > 0) {
	  header = rpmdbGetRecord(db, num);
	  info = get_info(header);

	  if (info != 0) av_push(pkgs, newRV_noinc((SV*)info));

	  headerFree(header);
	  num = rpmdbNextRecNum(db, num);
	  ++count;
	}
	rpmdbClose(db);
      } else croak("unable to open database");
    } else croak("cannot read rpm config files");
  } else croak("bad arguments list");
  RETVAL = count;
  OUTPUT:
  RETVAL


void
_parse_(fileno_or_rpmfile, flag, info, ...)
  SV* fileno_or_rpmfile
  SV* flag
  SV* info
  PREINIT:
  SV* provides = &PL_sv_undef;
  CODE:
  if (items > 3)
    provides = ST(3);
  if (SvROK(flag) && SvROK(info) && (provides == &PL_sv_undef || SvROK(provides))) {
    FD_t fd;
    int fd_is_hdlist;
    Header header;
    int_32 type, count;
    char **list;
    int_32 *flags;

    int bflag = 0;
    AV* iflag;
    HV* iinfo;
    HV* iprovides;
    SV** ret;
    I32 flag_len;
    STRLEN len;
    char* str;
    int i;

    if (SvIOK(fileno_or_rpmfile)) {
      fd = fdDup(SvIV(fileno_or_rpmfile));
      fd_is_hdlist = 1;
    } else {
      fd = fdOpen(SvPV_nolen(fileno_or_rpmfile), O_RDONLY, 0666);
      if (fd < 0) croak("unable to open rpm file %s", SvPV_nolen(fileno_or_rpmfile));
      fd_is_hdlist = 0;
    }

    if ((SvTYPE(SvRV(flag)) != SVt_PVAV) ||
	(SvTYPE(SvRV(info)) != SVt_PVHV) ||
	provides != &PL_sv_undef && (SvTYPE(SvRV(provides)) != SVt_PVHV))
      croak("bad arguments list");

    iflag = (AV*)SvRV(flag);
    iinfo = (HV*)SvRV(info);
    iprovides = (HV*)(provides != &PL_sv_undef ? SvRV(provides) : 0);

    /* examine flag and set up iflag, which is faster to fecth out */
    flag_len = av_len(iflag);
    for (i = 0; i <= flag_len; ++i) {
      ret = av_fetch(iflag, i, 0); if (!ret) continue;
      str = SvPV(*ret, len);

      switch (len) {
      case 4:
	if (!strncmp(str, "name", 4))      bflag |= HDFLAGS_NAME;
	else if (!strncmp(str, "arch", 4)) bflag |= HDFLAGS_ARCH;
	else if (!strncmp(str, "size", 4)) bflag |= HDFLAGS_SIZE;
	break;
      case 5:
	if (!strncmp(str, "group", 5))      bflag |= HDFLAGS_GROUP;
	else if (!strncmp(str, "sense", 5)) bflag |= HDFLAGS_SENSE;
	else if (!strncmp(str, "files", 5)) bflag |= HDFLAGS_FILES;
	break;
      case 7:
	if (!strncmp(str, "version", 7))      bflag |= HDFLAGS_VERSION;
	else if (!strncmp(str, "release", 7)) bflag |= HDFLAGS_RELEASE;
	else if (!strncmp(str, "dirsind", 7)) bflag |= HDFLAGS_DIRSIND;
	break;
      case 8:
	if (!strncmp(str, "requires", 8))      bflag |= HDFLAGS_REQUIRES;
	else if (!strncmp(str, "provides", 8)) bflag |= HDFLAGS_PROVIDES;
	else if (!strncmp(str, "filesind", 8)) bflag |= HDFLAGS_FILESIND;
	break;
      case 9:
	if (!strncmp(str, "obsoletes", 9))      bflag |= HDFLAGS_OBSOLETES;
	else if (!strncmp(str, "conflicts", 9)) bflag |= HDFLAGS_CONFLICTS;
	break;
      }
    }
    bflag |= HDFLAGS_NAME; /* this one should always be used */
    if (iprovides) bflag |= HDFLAGS_REQUIRES; /* not really usefull else */

    /* start the big loop,
       parse all header from fileno, then extract information to store into iinfo and iprovides. */
    while (fd_is_hdlist >= 0 ? (fd_is_hdlist > 0 ?
				((header=headerRead(fd, HEADER_MAGIC_YES)) != 0) :
				((fd_is_hdlist = -1), rpmReadPackageHeader(fd, &header, &i, NULL, NULL) == 0)) : 0) {
      char *name = get_name(header, RPMTAG_NAME);
      SV* sv_name = newSVpv(name, 0);
      HV* header_info = newHV();

      if (bflag & HDFLAGS_NAME)
	hv_store(header_info, "name", 4, SvREFCNT_inc(sv_name), 0);
      if (bflag & HDFLAGS_VERSION)
	hv_store(header_info, "version", 7, newSVpv(get_name(header, RPMTAG_VERSION), 0), 0);
      if (bflag & HDFLAGS_RELEASE)
	hv_store(header_info, "release", 7, newSVpv(get_name(header, RPMTAG_RELEASE), 0), 0);
      if (bflag & HDFLAGS_ARCH)
	hv_store(header_info, "arch", 4, newSVpv(get_name(header, RPMTAG_ARCH), 0), 0);
      if (bflag & HDFLAGS_GROUP)
	hv_store(header_info, "group", 5, newSVpv(get_name(header, RPMTAG_GROUP), 0), 0);
      if (bflag & HDFLAGS_SIZE)
	hv_store(header_info, "size", 4, newSViv(get_int(header, RPMTAG_SIZE)), 0);
      if (bflag & HDFLAGS_REQUIRES)
	hv_store(header_info, "requires", 8, get_table_sense(header,                 RPMTAG_REQUIRENAME,
							     bflag & HDFLAGS_SENSE ? RPMTAG_REQUIREFLAGS : 0,
							     bflag & HDFLAGS_SENSE ? RPMTAG_REQUIREVERSION : 0, iprovides), 0);
      if (bflag & HDFLAGS_PROVIDES)
	hv_store(header_info, "provides", 8, get_table_sense(header,                 RPMTAG_PROVIDENAME,
							     bflag & HDFLAGS_SENSE ? RPMTAG_PROVIDEFLAGS : 0,
							     bflag & HDFLAGS_SENSE ? RPMTAG_PROVIDEVERSION : 0, 0), 0);
      if (bflag & HDFLAGS_OBSOLETES)
	hv_store(header_info, "obsoletes", 9, get_table_sense(header,                 RPMTAG_OBSOLETENAME,
							      bflag & HDFLAGS_SENSE ? RPMTAG_OBSOLETEFLAGS : 0,
							      bflag & HDFLAGS_SENSE ? RPMTAG_OBSOLETEVERSION : 0, 0), 0);
      if (bflag & HDFLAGS_CONFLICTS)
	hv_store(header_info, "conflicts", 9, get_table_sense(header,                 RPMTAG_CONFLICTNAME,
							      bflag & HDFLAGS_SENSE ? RPMTAG_CONFLICTFLAGS : 0,
							      bflag & HDFLAGS_SENSE ? RPMTAG_CONFLICTVERSION : 0, 0), 0);
      if (iprovides || (bflag & HDFLAGS_FILES)) {
	/* at this point, there is a need to parse all files to update provides of needed files,
	   or to store them. */
	AV* table_files = bflag & HDFLAGS_FILES ? newAV() : 0;
	char ** baseNames, ** dirNames;
	int_32 * dirIndexes;

	headerGetEntry(header, RPMTAG_OLDFILENAMES, &type, (void **) &list, &count);

	if (list) {
	  for (i = 0; i < count; i++) {
	    SV** isv;

	    len = strlen(list[i]);

	    if (iprovides && (isv = hv_fetch(iprovides, list[i], len, 0)) != 0) {
	      if (!SvROK(*isv) || SvTYPE(SvRV(*isv)) != SVt_PVAV) {
		SV* choice_table = (SV*)newAV();
		SvREFCNT_dec(*isv); /* drop the old as we are changing it */
		*isv = choice_table ? newRV_noinc(choice_table) : &PL_sv_undef;
	      }
	      if (*isv != &PL_sv_undef) av_push((AV*)SvRV(*isv), SvREFCNT_inc(sv_name));
	    }
	    /*	    if (iprovides && hv_exists(iprovides, list[i], len))
		    hv_store(iprovides, list[i], len, newSVpv(name, 0), 0); */
	    if (table_files)
	      av_push(table_files, newSVpv(list[i], len));
	  }
	}

	headerGetEntry(header, RPMTAG_BASENAMES, &type, (void **) &baseNames, 
		       &count);
	headerGetEntry(header, RPMTAG_DIRINDEXES, &type, (void **) &dirIndexes, 
		       NULL);
	headerGetEntry(header, RPMTAG_DIRNAMES, &type, (void **) &dirNames, NULL);

	if (baseNames && dirNames && dirIndexes) {
	  char buff[4096];
	  char *p;

	  for(i = 0; i < count; i++) {
	    SV** isv;

	    len = strlen(dirNames[dirIndexes[i]]);
	    if (len >= sizeof(buff)) continue;
	    memcpy(p = buff, dirNames[dirIndexes[i]], len + 1); p += len;
	    len = strlen(baseNames[i]);
	    if (p - buff + len >= sizeof(buff)) continue;
	    memcpy(p, baseNames[i], len + 1); p += len;

	    if (iprovides && (isv = hv_fetch(iprovides, buff, p - buff, 0)) != 0) {
	      if (!SvROK(*isv) || SvTYPE(SvRV(*isv)) != SVt_PVAV) {
		SV* choice_table = (SV*)newAV();
		SvREFCNT_dec(*isv); /* drop the old as we are changing it */
		*isv = choice_table ? newRV_noinc(choice_table) : &PL_sv_undef;
	      }
	      if (*isv != &PL_sv_undef) av_push((AV*)SvRV(*isv), SvREFCNT_inc(sv_name));
	    }
	    if (table_files)
	      av_push(table_files, newSVpv(buff, p - buff));
	  }
	}

	if (table_files)
	  hv_store(header_info, "files", 5, newRV_noinc((SV*)table_files), 0);
      }
      if (iprovides) {
	/* we have to examine provides to update the hash here. */
	headerGetEntry(header, RPMTAG_PROVIDENAME, &type, (void **) &list, &count);

	if (list) {
	  for (i = 0; i < count; i++) {
	    SV** isv;

	    len = strlen(list[i]);

	    isv = hv_fetch(iprovides, list[i], len, 1);
	    if (!SvROK(*isv) || SvTYPE(SvRV(*isv)) != SVt_PVAV) {
	      SV* choice_table = (SV*)newAV();
	      SvREFCNT_dec(*isv); /* drop the old as we are changing it */
	      *isv = choice_table ? newRV_noinc(choice_table) : &PL_sv_undef;
	    }
	    if (*isv != &PL_sv_undef) av_push((AV*)SvRV(*isv), SvREFCNT_inc(sv_name));
	  }
	}
      }

      /* once the hash header_info is built, store a reference to it
	 in iinfo.
	 note sv_name is not incremented here, it has the default value of before. */
      hv_store_ent(iinfo, sv_name, newRV_noinc((SV*)header_info), 0);

      /* dispose of some memory */
      headerFree(header);
    }
    fdClose(fd);
  } else croak("bad arguments list");