#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <rpm/rpmlib.h>
#include <rpm/header.h>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <fstream>
#include <algorithm>


string get_name(Header header, int_32 tag) {
  int_32 type, count;
  char *name;

  headerGetEntry(header, tag, &type, (void **) &name, &count);
  return string(name);
}

int get_int(Header header, int_32 tag) {
  int_32 type, count;
  int *i;

  headerGetEntry(header, tag, &type, (void **) &i, &count);
  return *i;
}

vector<string> get_info(Header header, int_32 tag) {
  int_32 type, count, i;
  vector<string> r;
  char **list;

  headerGetEntry(header, tag, &type, (void **) &list, &count);
  if (list) {
    r.reserve(count);
    for (i = 0; i < count; i++) r.push_back(list[i]);
  }
  return r;
}

vector<string> get_files(Header header) {
  int_32 type, count, i;
  vector<string> r;
  char **list;
  char ** baseNames, ** dirNames;
  int_32 * dirIndexes;

  headerGetEntry(header, RPMTAG_BASENAMES, &type, (void **) &baseNames, 
		 &count);
  headerGetEntry(header, RPMTAG_DIRINDEXES, &type, (void **) &dirIndexes, 
		 NULL);
  headerGetEntry(header, RPMTAG_DIRNAMES, &type, (void **) &dirNames, NULL);
  
  if (baseNames && dirNames && dirIndexes) {
    r.reserve(count);
    for(i = 0; i < count; i++) {
      string s(dirNames[dirIndexes[i]]);
      s += baseNames[i];
      r.push_back(s);
    }
  }
  return r;
}

template<class V, class C> C sum(const V &v, const C &join = C()) {
  typename V::const_iterator p, q;
  C s = C();
  if (v.begin() != v.end()) {
    for (p = q = v.begin(), q++; q != v.end(); p = q, q++) s += *p + join;
    s += *p;
  }
  return s;
}

template<class A, class B> void map_insert(map<A, set<B> > &m, const A &a, const B &b) {
  if (m.find(a) == m.end()) m[a] = *(new set<B>);
  m[a].insert(b);
}

template<class A> bool in(const A &a, const vector<A> &v) {
  vector<A>::const_iterator p;
  for (p = v.begin(); p != v.end(); p++) if (*p == a) return 1;
  return 0;
}

typedef vector<string>::iterator IT;

#define myerror(e) { checknberrors(); e; return; }

struct pack {
  int nberrors;
  static const int max_errors = 20;
  ofstream html, text;
  vector<string> packages;
  map<string, string> short_name;
  map<string, int> size;
  map<string, vector<string> > requires;
  map<string, set<string> > provides;
  map<string, set<set<string> > > pack_requires;

  pack(string name) : nberrors(0), html((name + ".html").c_str()), text(name.c_str()) {
    if (!html || !text) {
      cerr << "rpmpackdeps: can't output files\n";
      exit(1);
    }
  }

  void checknberrors() {
    if (nberrors++ == max_errors) {
      cerr << "rpmpackdeps: too many errors, leaving!\n";
      exit(1);
    }
  }

  int get_package_info(Header header) {

    string s_name = get_name(header, RPMTAG_NAME);
    string name = s_name + "-" + get_name(header, RPMTAG_VERSION) + "-" + get_name(header, RPMTAG_RELEASE);

    packages.push_back(name);
    short_name[name] = s_name;
    requires[name] = get_info(header, RPMTAG_REQUIRENAME);
    size[name] = get_int(header, RPMTAG_SIZE);
    map_insert(provides, s_name, name);

    vector<string> provide = get_info(header, RPMTAG_PROVIDES);
    vector<string> files = get_info(header, RPMTAG_OLDFILENAMES);
    for (IT p = provide.begin(); p != provide.end(); p++) map_insert(provides, *p, name);
    for (IT p = files.begin(); p != files.end(); p++) map_insert(provides, *p, name);

    vector<string> newfiles = get_files(header);
    for (IT p = newfiles.begin(); p != newfiles.end(); p++) map_insert(provides, *p, name);

    headerFree(header);
    return 1;
  }
  
  void sort() {
    std::sort(packages.begin(), packages.end());
  }

  set<set<string> > closure(const string &package) {
    if (pack_requires.find(package) != pack_requires.end()) return pack_requires[package];

    set<set<string> > l;
    pack_requires[package] = l; // to avoid circular graphs

    for (IT q = requires[package].begin(); q != requires[package].end(); q++) {
      set<string> s;
      if (provides.find(*q) == provides.end()) { 
	cerr << package << " requires " << *q << " but no package provide it\n"; 
	s.insert("NOTFOUND_" + *q);
      } else {
	for (set<string>::const_iterator p = provides[*q].begin(); p != provides[*q].end(); p++) {
	  if (*p == package) { s.clear(); break; }
	  s.insert(*p);
	}

	if (provides[*q].size() == 1) {
#ifdef CLOSURE
	  set<set<string> > c = closure(st);
	  l.insert(c.begin(), c.end());
#endif
	}
      }
      l.insert(s);
    }
    return pack_requires[package] = l;
  }
  
  void print_deps() {
    html << "<html><dl>\n";
    for (IT package = packages.begin(); package != packages.end(); package++) {
      set<set<string> > l = closure(*package);

      text << *package << " " << size[*package] << " ";
      html << "<dt>" << *package << "<dd>";
      for (set<set<string> >::const_iterator p = l.begin(); p != l.end(); p++) {
	text << sum(*p, string("|")) << " ";
	html << sum(*p, string(" or ")) << "<br>";
      }
      text << "\n";
      html << "\n";
    }
    html << "</dl></html>\n";
  }
};

void printHelp(char * name)
{
  cerr << "usage: \n" << name << " -h name hdlists...\n" << name << " -f name rpms...\n";
}

int main(int argc, char **argv) 
{
  if (argc > 3) {
    if (!strcmp(argv[1],"-h")) {    //Mode Hdlist
      pack p(argv[2]);
      for (int i = 3; i < argc; i++) 
	{
	  FD_t fd = strcmp(argv[i], "-") == 0 ? fdDup(STDIN_FILENO) : fdOpen(argv[i], O_RDONLY, 0);
	  if (fdFileno(fd) < 0) cerr << "rpmpackdeps: cannot open file " << argv[i] << "\n";
	  else  {
	      Header header;
	      while ((header=headerRead(fd, HEADER_MAGIC_YES))) p.get_package_info(header);
	  }
	  fdClose(fd);
	}
      p.sort();
      p.print_deps();
      return 0;
    }
    else {
      int i=2;
      if (!strcmp(argv[1],"-f")) i++;
      //Mode rpm
      pack p(argv[2]);
      for (int i = 3; i < argc; i++) 
	{
	  FD_t fd = fdOpen(argv[i], O_RDONLY, 0);
	  if (fdFileno(fd) < 0) cerr << argv[0] << ": cannot open file " << argv[i] << "\n";
	  Header header;
	  if (rpmReadPackageInfo(fd, NULL, &header)) cerr << argv[0] <<" : "  << argv[i] << " does not appear to be a RPM package\n";
	  else p.get_package_info(header);
	  fdClose(fd);
	}
      p.sort();
      p.print_deps();
      return 0;
    }    
  }
  else 
    {
      printHelp(argv[0]);
      return 1;
    }   
}

