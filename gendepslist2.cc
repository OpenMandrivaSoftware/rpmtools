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

#define COMPATIBILITY


/********************************************************************************/
/* C++ template functions *******************************************************/
/********************************************************************************/
template<class V, class C> C sum(const V &v, const C &join = C()) {
  typename V::const_iterator p, q;
  C s = C();
  if (v.begin() != v.end()) {
    for (p = q = v.begin(), q++; q != v.end(); p = q, q++) s += *p + join;
    s += *p;
  }
  return s;
}

vector<string> split(char sep, const string &l) {
  vector<string> r;
  for (int pos = 0, pos2 = 0; pos2 >= 0;) {
    pos2 = l.find(sep, pos);
    r.push_back(l.substr(pos, pos2 - pos));
    pos = pos2 + 1;
  }
  return r;
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
template<class A> bool in(const A &a, const set<A> &m) {
  return m.find(a) != m.end();
}
template<class A, class B> bool in(const A &a, const map<A,B> &m) {
  return m.find(a) != m.end();
}

template<class A, class B> map<A,B> &set2map(const set<A> &s) {
  map<A,B> map;
  set<A>::const_iterator p;
  for (p = s.begin(); p != s.end(); p++) map[*p] = *(new B);
  return map;
}

template<class A, class B> void add(set<A> &v1, const B &v2) {
  typename B::const_iterator p;
  for (p = v2.begin(); p != v2.end(); p++) v1.insert(*p);
}
template<class A, class B> void add(vector<A> &v1, const B &v2) {
  typename B::const_iterator p;
  for (p = v2.begin(); p != v2.end(); p++) v1.push_back(*p);
}

typedef vector<string>::iterator ITv;
typedef set<string>::iterator ITs;
typedef map<string, set<string> >::iterator ITms;




/********************************************************************************/
/* header extracting functions **************************************************/
/********************************************************************************/
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
    free(list);
  }
  return r;
}

vector<string> get_files(Header header) {
  int_32 type, count, i;
  char ** baseNames, ** dirNames;
  int_32 * dirIndexes;

#ifdef COMPATIBILITY
  // deprecated one
  vector<string> r = get_info(header, RPMTAG_OLDFILENAMES);
#else
  vector<string> r;
#endif

  headerGetEntry(header, RPMTAG_BASENAMES, &type, (void **) &baseNames, &count);
  headerGetEntry(header, RPMTAG_DIRINDEXES, &type, (void **) &dirIndexes, NULL);
  headerGetEntry(header, RPMTAG_DIRNAMES, &type, (void **) &dirNames, NULL);
  
  if (baseNames && dirNames && dirIndexes) {
    r.reserve(count);
    for(i = 0; i < count; i++) {
      string s(dirNames[dirIndexes[i]]);
      s += baseNames[i];
      r.push_back(s);
    }
    free(baseNames);
    free(dirNames);
  }
  return r;
}

/********************************************************************************/
/* gendepslist ******************************************************************/
/********************************************************************************/
int nb_hdlists;
vector<string> packages;
map<string, int> sizes;
map<int, set<string> > hdlist2names;
map<string, string> name2fullname;
map<string, vector<string> > requires, frequires;
map<string, vector<string> > provided_by, fprovided_by;

void getRequires(FD_t fd, int) {
  set<string> all_requires, all_frequires;
  Header header;

  while ((header=headerRead(fd, HEADER_MAGIC_YES))) 
  {
    string s_name = get_name(header, RPMTAG_NAME);
    string name = s_name + "-" + get_name(header, RPMTAG_VERSION) + "-" + get_name(header, RPMTAG_RELEASE);
    vector<string> l = get_info(header, RPMTAG_REQUIRENAME);
    
    for (ITv p = l.begin(); p != l.end(); p++) {      
      ((*p)[0] == '/' ?     frequires :     requires)[name].push_back(*p);
      ((*p)[0] == '/' ? all_frequires : all_requires).insert(*p);
    }
    headerFree(header);
  }
  for (ITs p = all_requires.begin();  p != all_requires.end();  p++)  provided_by[*p] = *(new vector<string>);
  for (ITs p = all_frequires.begin(); p != all_frequires.end(); p++) fprovided_by[*p] = *(new vector<string>);
}

void getProvides(FD_t fd, int current_hdlist) {
  Header header;
  while ((header=headerRead(fd, HEADER_MAGIC_YES))) 
  {
    string s_name = get_name(header, RPMTAG_NAME);
    string name = s_name + "-" + get_name(header, RPMTAG_VERSION) + "-" + get_name(header, RPMTAG_RELEASE);

    packages.push_back(name);
    name2fullname[s_name] = name;
    hdlist2names[current_hdlist].insert(name);
    sizes[name] = get_int(header, RPMTAG_SIZE);

    if (in(s_name, provided_by)) provided_by[s_name].push_back(name);

    vector<string> provides = get_info(header, RPMTAG_PROVIDES);
    for (ITv p = provides.begin(); p != provides.end(); p++)
      if (in(*p, provided_by)) provided_by[*p].push_back(name);

    vector<string> fprovides = get_files(header);
    for (ITv p = fprovides.begin(); p != fprovides.end(); p++)
      if (in(*p, fprovided_by)) fprovided_by[*p].push_back(name);

    headerFree(header);
  }
}

set<string> getDep_(const string &dep, vector<string> &l) {
  set<string> r;
  switch (l.size()) 
  {
  case 0: 
    r.insert((string) "NOTFOUND_" + dep);
    break;
  case 1: 
    r.insert(l[0]);
    break;
  default: 
    r.insert(sum(l, (string)"|"));
  }
  return r;
}

set<string> getDep(const string &name) {
  set<string> r;
  r.insert(name);
  for (ITv p =  requires[name].begin(); p !=  requires[name].end(); p++) add(r, getDep_(*p,  provided_by[*p]));
  for (ITv p = frequires[name].begin(); p != frequires[name].end(); p++) add(r, getDep_(*p, fprovided_by[*p]));
  return r;
}

map<string, set<string> > closure(const map<string, set<string> > &names) {
  map<string, set<string> > r = names;
  
  map<string, set<string> > reverse;
  for (ITv i = packages.begin(); i != packages.end(); i++) reverse[*i] = *(new set<string>);

  for (ITms i = r.begin(); i != r.end(); i++)
    for (ITs j = i->second.begin(); j != i->second.end(); j++) 
      reverse[*j].insert(i->first);

  for (ITms i = r.begin(); i != r.end(); i++) {
    set<string> rev = reverse[i->first];
    for (ITs j = rev.begin(); j != rev.end(); j++) {

      for (ITs k = i->second.begin(); k != i->second.end(); k++) {
	r[*j].insert(*k);
	reverse[*k].insert(*j);
      }

    }
  }
  return r;
}


//struct cmp : public binary_function<string,string,bool> {
//  bool operator()(const string &a, const string &b) {
//    int na = closed[a].size();
//    int nb = closed[b].size();
//    return na < nb;
//  }
//};

inline int verif(int npack, int ndep, const string &package, const string &dep) {
  if (ndep > npack) cerr << package << " requires " << dep << " which is not in the same hdlist\n";
  return ndep;
}

void printDepslist(ofstream *out1, ofstream *out2) {

  map<string, set<string> > names;  
  for (ITv p = packages.begin(); p != packages.end(); p++) {
    set<string> s = getDep(*p);
    s.erase(*p);
    names[*p] = s;
    if (out1) *out1 << *p << " " << sizes[*p] << " " << sum(s, (string) " ") << "\n";
  }
  if (out2 == 0) return;

  map<string, set<string> > closed = closure(names);
  for (ITms p = closed.begin(); p != closed.end(); p++) p->second.erase(p->first);
  names = closed;

  vector<string> packages;
  set<string> list = hdlist2names[0];
  int nb2hdlist[names.size()];
  int i = 0;
  string n;

  map<string,int> nb_deps_done;
  for (ITms p = names.begin(); p != names.end(); p++) nb_deps_done[p->first] = 0;



  for (int i = -1, nb = 0; i < nb_hdlists; i++, nb++) {
    set<string> list;

    if (i == -1) {
      list.insert(name2fullname["filesystem"]); nb_deps_done[name2fullname["filesystem"]] = 10;
      list.insert(name2fullname["setup"]);      nb_deps_done[name2fullname["setup"]]      = 10;
      add(list, names[name2fullname["basesystem"]]);
      list.insert(name2fullname["basesystem"]);
      for (ITs p = list.begin(); p != list.end(); p++) {
	if (p->find('|') != string::npos) {
	  list.erase(*p);
	  vector<string> l = split('|', *p);
	  for (ITv k = l.begin(); k != l.end(); k++) {
	    list.insert(*k);
	    add(list, names[*k]);
	  }
	}
      }
      for (ITs p = list.begin(); p != list.end(); p++) hdlist2names[0].erase(*p);
    } else {
      list = hdlist2names[i];
    }
    while (list.begin() != list.end()) {
      int l_best = 9999;

      for (ITs p = list.begin(); p != list.end(); p++) {
	if (p->compare("NOTFOUND_") > 1) {
	  list.erase(*p);
	  continue;
	}
	int lo = names[*p].size() - nb_deps_done[*p];
	if (lo < l_best) {
	  l_best = lo;
	  n = *p;
	  if (l_best == -1) break;
	}
      }
      names.erase(n);
      list.erase(n);
      nb2hdlist[nb++] = i;
      packages.push_back(n);
      for (ITms p = names.begin(); p != names.end(); p++) p->second.erase(n);
    }
  }
  cerr << "ordering done\n";

  i = 0;
  map<string,int> where;
  for (ITv p = packages.begin(); p != packages.end(); p++, i++) where[*p] = i;

  i = 0;
  for (ITv p = packages.begin(); p != packages.end(); p++, i++) {
    set<string> dep = closed[*p];
    *out2 << *p << " " << sizes[*p];
    for (ITs q = dep.begin(); q != dep.end(); q++) {
      if (q->find('|') != string::npos) {
	vector<string> l = split('|', *q);

	int skip = 0;
	for (ITv k = l.begin(); k != l.end(); k++) if (*p == *k) { skip = 1; break; }
	if (skip) continue;

	*out2 << " ";
	int previous = 0;
	for (ITv k = l.begin(); k != l.end(); k++) {
	  if (previous) *out2 << "|";
	  previous = 1;

	  verif(nb2hdlist[i], nb2hdlist[where[*k]], *p, *k);
	  *out2 << where[*k];
	}
      } else if (q->compare("NOTFOUND_") > 1) {
	*out2 << " " << *q;
      } else {
	verif(nb2hdlist[i], nb2hdlist[where[*q]], *p, *q);
	*out2 << " " << where[*q];
      }
    }
    *out2 << "\n";
  }
}

void hdlists(void (*f)(FD_t, int), const char *hdlist, int current_hdlist) {
    FILE *pipe = popen(((string) "bzip2 -d <" + hdlist + " 2>/dev/null").c_str(), "r");

    f(fdDup(fileno(pipe)), current_hdlist);

    if (fclose(pipe) != 0) {
      cerr << "bad hdlist " << hdlist << "\n";
      exit(1);
    }
}

int main(int argc, char **argv) 
{
  ofstream *out1 = 0, *out2 = 0;
  if (argc > 2 && (string)argv[1] == "-o") {
    out1 = new ofstream(argv[2]);
    out2 = new ofstream(((string)argv[2] + ".ordered").c_str());
    argc -= 2; argv += 2;
  } else {
    out1 = new ofstream(STDOUT_FILENO);
  }
  if (argc < 2) {
    cerr << "usage: gendepslist2 [-o <depslist>] hdlists_cz2...\n";
    return 1;
  }

  nb_hdlists = argc - 1;

  for (int i = 1; i < argc; i++) hdlists(getRequires, argv[i], i - 1);
  cerr << "getRequires done\n";

  for (int i = 1; i < argc; i++) hdlists(getProvides, argv[i], i - 1);
  cerr << "getProvides done\n";

  printDepslist(out1, out2);
  delete out1; 
  delete out2;
}
