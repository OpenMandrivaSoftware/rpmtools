#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <rpm/rpmlib.h>
#include <rpm/header.h>

static Header header;

#define die(f) { perror(f); exit(1); }

rpmdb open_rpmdb(void) {
  rpmdb db;
  if (rpmdbOpen("", &db, O_RDONLY, 0644)) die("rpmdbOpen");
  return db;
}

char *get(int_32 tag) {
  int_32 type, count;
  char *s;
  if (headerGetEntry(header, tag, &type, (void **) &s, &count) != 1) die("bad header ??");
  return s;
}


int main() {
  rpmTransactionSet trans;
  struct rpmDependencyConflict *conflicts;
  int numConflicts;
  rpmdb db;
  int i;

  rpmReadConfigFiles(NULL, NULL);

  db = open_rpmdb();

  for(i = rpmdbFirstRecNum(db); i; i = rpmdbNextRecNum(db, i)) {
    trans = rpmtransCreateSet(db, NULL);
    rpmtransRemovePackage(trans, i);
    if (rpmdepCheck(trans, &conflicts, &numConflicts)) die("rpmdepCheck");
    if (numConflicts == 0) {
      header = rpmdbGetRecord(db, i);
      printf("%s-%s-%s\n", get(RPMTAG_NAME), get(RPMTAG_VERSION), get(RPMTAG_RELEASE));
      headerFree(header);
    }
    rpmdepFreeConflicts(conflicts, numConflicts);
    rpmtransFree(trans);
  }
  exit(0);
}
