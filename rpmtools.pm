package rpmtools;

use strict;
use vars qw($VERSION @ISA);

require DynaLoader;

@ISA = qw(DynaLoader);
$VERSION = '2.3';

bootstrap rpmtools $VERSION;

=head1 NAME

rpmtools - Mandrake perl tools to handle rpm files and hdlist files

=head1 SYNOPSYS

    require rpmtools;

    my $params = new rpmtools;

    $params->read_hdlists("/export/Mandrake/base/hdlist.cz",
                          "/export/Mandrake/base/hdlist2.cz");
    $params->read_rpms("/RPMS/rpmtools-2.1-5mdk.i586.rpm");
    $params->compute_depslist();

    my $db = $params->db_open("");
    $params->db_traverse_tag($db,
                             "name", \@names,
                             [ qw(name version release) ],
                             sub {
        my ($p) = @_;
        print "$p->{name}-$p->{version}-$p->{release}\n";
    });
    $params->db_traverse($db,
                         [ qw(name version release) ],
                         sub {
        my ($p) = @_;
        print "$p->{name}-$p->{version}-$p->{release}\n";
    });
    $params->db_close($db);

    $params->read_depslist(\*STDIN);
    $params->write_depslist(\*STDOUT);

    rpmtools::version_compare("1.0.23", "1.0.4");

=head1 DESCRIPTION

C<rpmtools> extend perl to manipulate hdlist file used by
Linux-Mandrake distribution to compute dependancy file.

=head1 SEE ALSO

parsehdlist command is a simple hdlist parser that allow interactive mode
use by DrakX upgrade algorithms.

=head1 COPYRIGHT

Copyright (C) 2000 MandrakeSoft <fpons@mandrakesoft.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut

#- build an empty params struct that can be used to compute dependancies.
sub new {
    my ($class, @tags) = @_;
    my %tags; @tags{@_} = ();
    bless {
	   flags         => [ qw(name version release size arch group requires provides),
			      grep { exists $tags{$_} } qw(sense files obsoletes conflicts conffiles) ],
	   info          => {},
	   depslist      => [],
	   provides      => {},
	  }, $class;
}

#- read one or more hdlist files, use packdrake for decompression.
sub read_hdlists {
    my ($params, @hdlists) = @_;

    local (*I, *O); pipe I, O;
    if (my $pid = fork()) {
	close O;

	rpmtools::_parse_(fileno *I, $params->{flags}, $params->{info}, $params->{provides});

	close I;
	waitpid $pid, 0;
    } else {
	close I;
	open STDOUT, ">&O" or die "unable to redirect output";

	require packdrake;
	packdrake::cat_archive(@hdlists);

	close O;
	exit 0;
    }
    1;
}

#- build an hdlist from a list of files.
sub build_hdlist {
    my ($params, $noclean, $ratio, $dir, $hdlist, @rpms) = @_;
    my %names;

    #- build a working directory which will hold rpm headers.
    $dir ||= '.';
    -d $dir or mkdir $dir, 0755 or die "cannot create directory $dir\n";

    foreach (@rpms) {
	my ($key, $name) = /(([^\/]*)-[^-]*-[^-]*\.[^\/\.]*)\.rpm$/ or next;
	system("rpm2header '$_' > '$dir/$key'") unless -e "$dir/$key";
	$? == 0 or unlink("$dir/$key"), die "bad rpm $_\n";
	-s "$dir/$key" or unlink("$dir/$key"), die "bad rpm $_\n";
	push @{$names{$name} ||= []}, $key;
    }

    #- compression ratio are not very high, sample for cooker
    #- gives the following (main only and cache fed up):
    #- ratio compression_time  size
    #-   9       21.5 sec     8.10Mb   -> good for installation CD
    #-   6       10.7 sec     8.15Mb
    #-   5        9.5 sec     8.20Mb
    #-   4        8.6 sec     8.30Mb   -> good for urpmi
    #-   3        7.6 sec     8.60Mb
    open B, "| packdrake -b${ratio}ds '$hdlist' '$dir' 400000";
    foreach (@{$params->{depslist}}) {
	if (my $keys = delete $names{$_->{name}}) {
	    print B "$_\n" foreach @$keys;
	}
    }
    foreach (values %names) {
	print B "$_\n" foreach @$_;
    }
    close B or die "packdrake failed\n";

    system("rm", "-rf", $dir) unless $dir eq '.' || $noclean;
}

#- read one or more rpm files.
sub read_rpms {
    my ($params, @rpms) = @_;

    map { rpmtools::_parse_($_, $params->{flags}, $params->{info}, $params->{provides}) } @rpms;
}

#- compute dependancies, result in stored in info values of params.
#- operations are incremental, it is possible to read just one hdlist, compute
#- dependancies and read another hdlist, and again.
sub compute_depslist {
    my ($params) = @_;

    #- avoid recomputing already present infos, take care not to modify
    #- existing entries, as the array here is used instead of values of infos.
    my @info = grep { ! exists $_->{id} } values %{$params->{info}};

    #- speed up the search by giving a provide from all packages.
    #- and remove all dobles for each one !
    foreach (@info) {
	push @{$params->{provides}{$_->{name}} ||= []}, $_->{name};
    }

    #- remove all dobles for each provides.
    foreach (keys %{$params->{provides}}) {
	$params->{provides}{$_} or next;
	my %provides; @provides{@{$params->{provides}{$_}}} = ();
	$params->{provides}{$_} = [ keys %provides ];
    }

    #- take into account in which hdlist a package has been found.
    #- this can be done by an incremental take into account generation
    #- of depslist.ordered part corresponding to the hdlist.
    #- compute closed requires, do not take into account choices.
    foreach (@info) {
	my %required_packages;
	my @required_packages;
	my %requires; @requires{@{$_->{requires} || []}} = ();
	my @requires = keys %requires;

	while (my $req = shift @requires) {
	    $req eq 'basesystem' and next; #- never need to requires basesystem directly as always required! what a speed up!
	    ref $req or $req = $params->{provides}{$req} || ($req =~ /rpmlib\(/ ? [] :
							     [ ($req !~ /NOTFOUND_/ && "NOTFOUND_") . $req ]);
	    if (@$req > 1) {
		#- this is a choice, no closure need to be done here.
		exists $requires{$req} or push @required_packages, $req;
		$requires{$req} = undef;
	    } else {
		#- this could be nothing if the provides is a file not found.
		#- and this has been fixed above.
		foreach (@$req) {
		    my $info = $params->{info}{$_};
		    $required_packages{$_} = undef; $info or next;
		    if ($info->{deps} && !$info->{requires}) {
			#- the package has been read from an ordered depslist file, and need
			#- to rebuild its requires tags, so it can safely be used here.
			my @rebuild_requires;
			foreach (split ' ', $info->{deps}) {
			    if (/\|/) {
				push @rebuild_requires, [ map { $params->{depslist}[$_]{name} || $_ } split /\|/, $_ ];
			    } else {
				push @rebuild_requires, $params->{depslist}[$_]{name} || $_;
			    }
			}
			$info->{requires} = \@rebuild_requires;
		    }
		    foreach (@{$info->{requires} || []}) {
			unless (exists $requires{$_}) {
			    $requires{$_} = undef;
			    push @{ref $_ ? \@required_packages : \@requires}, $_;
			}
		    }
		}
	    }
	}
	unshift @required_packages, keys %required_packages;

	delete $_->{requires}; #- affecting it directly make perl crazy, oops for rpmtools. TODO
	$_->{requires} = \@required_packages;
    }

    #- sort packages, expand choices and closure again.
    my %ordered;
    foreach (@info) {
	my %requires;
	my @requires = ($_->{name});
	while (my $dep = shift @requires) {
	    foreach (@{$params->{info}{$dep} && $params->{info}{$dep}{requires} || []}) {
		if (ref $_) {
		    foreach (@$_) {
			unless (exists $requires{$_}) {
			    $requires{$_} = undef;
			    push @requires, $_;
			}
		    }
		} else {
		    unless (exists $requires{$_}) {
			$requires{$_} = undef;
			push @requires, $_;
		    }
		}
	    }
	}

	if ($_->{name} eq 'basesystem') {
	    foreach (keys %requires) {
		$ordered{$_} += 10001;
	    }
	} else {
	    foreach (keys %requires) {
		++$ordered{$_};
	    }
	}
    }
    #- setup, filesystem and basesystem should be at the beginning.
    @ordered{qw(ldconfig readline termcap libtermcap bash sash glibc setup filesystem basesystem)} =
      (100000, 90000, 80000, 70000, 60000, 50000, 40000, 30000, 20000, 10000);

    #- compute base flag, consists of packages which are required without
    #- choices of basesystem and are ALWAYS installed. these packages can
    #- safely be removed from requires of others packages.
    foreach (@{$params->{info}{basesystem}{requires}}) {
	ref $_ or $params->{info}{$_} and $params->{info}{$_}{base} = undef;
    }
    #- some package are always installed as base and can safely be marked as such.
    foreach (qw(basesystem glibc)) {
	$params->{info}{$_} and $params->{info}{$_}{base} = undef;
    }

    #- give an id to each packages, start from number of package already
    #- registered in depslist.
    my $global_id = scalar @{$params->{depslist}};
    foreach (sort { $ordered{$b->{name}} <=> $ordered{$a->{name}} } @info) {
	$_->{id} = $global_id++;
    }

    #- recompute requires to use packages id, drop any base packages or
    #- reference of a package to itself.
    foreach my $pkg (sort { $a->{id} <=> $b->{id} } @info) {
	my ($id, $base, %requires_id, @requires_id);
	foreach (@{$pkg->{requires}}) {
	    if (ref $_) {
		#- all choices are grouped together at the end of requires,
		#- this allow computation of dropable choices.
		my ($to_drop, @choices_base_id, @choices_id);
		foreach (@$_) {
		    my ($id, $base) = $params->{info}{$_} ? ($params->{info}{$_}{id}, exists $params->{info}{$_}{base}) : ($_, 0);
		    $base and push @choices_base_id, $id;
		    $base &&= ! exists $pkg->{base};
		    $to_drop ||= $id == $pkg->{id} || $requires_id{$id} || $base;
		    push @choices_id, $id;
		}

		#- package can safely be dropped as it will be selected in requires directly.
		$to_drop and next;

		#- if a base package is in a list, keep it instead of the choice.
		if (@choices_base_id) {
		    ($id, $base) = ($choices_base_id[0], 1);
		} else {
		    my $choices_key = join '|', @choices_id;
		    exists $requires_id{$choices_key} or push @requires_id, \@choices_id;
		    $requires_id{$choices_key} = undef;
		    next;
		}
	    } else {
		($id, $base) = $params->{info}{$_} ? ($params->{info}{$_}{id}, exists $params->{info}{$_}{base}) : ($_, 0);
	    }

	    #- select individual package.
	    $base &&= ! exists $pkg->{base};
	    $requires_id{$id} = $_;
	    $id == $pkg->{id} || $base or push @requires_id, $id;
	}
	#- cannot remove requires values as they are necessary for closure on incremental job.
	$pkg->{deps} = join(' ', map { join '|', @{ref $_ ? $_ : [$_]} } @requires_id);
	push @{$params->{depslist}}, $pkg;
    }
    1;
}

#- read depslist.ordered file, as if it was computed internally.
sub read_depslist {
    my ($params, $FILE) = @_;
    my $global_id = scalar @{$params->{depslist}};

    local $_;
    while (<$FILE>) {
	chomp; /^\s*#/ and next;
	my ($name, $version, $release, $size, $deps) = /^(\S*)-([^-\s]+)-([^-\s]+)\s+(\d+)\s*(.*)/;

	#- store values here according to it.
	push @{$params->{depslist}}, $params->{info}{$name} = {
							       name        => $name,
							       version     => $version,
							       release     => $release,
							       size        => $size,
							       deps        => $deps,
							       id          => $global_id++,
							      };
    }

    #- compute base flag, consists of packages which are required without
    #- choices of basesystem and are ALWAYS installed. these packages can
    #- safely be removed from requires of others packages.
    if ($params->{info}{basesystem} && ! exists $params->{info}{basesystem}{base}) {
	my @requires_id;
	foreach (split ' ', $params->{info}{basesystem}{deps}) {
	    /\|/ or push @requires_id, $_;
	}
	foreach ($params->{info}{basesystem}{id}, @requires_id) {
	    $params->{depslist}[$_] and $params->{depslist}[$_]{base} = undef;
	}
    }
    1;
}

#- relocate depslist array to use only the most recent packages,
#- reorder info hashes too in the same manner.
sub relocate_depslist {
    my ($params) = @_;
    my $relocated_entries = 0;

    foreach (@{$params->{depslist} || []}) {
	if ($params->{info}{$_->{name}} != $_) {
	    #- at this point, it is sure there is a package that
	    #- is multiply defined and this should be fixed.
	    #- first correct info hash, then a second pass on depslist
	    #- is required to relocate its entries.
	    my $cmp_version = version_compare($_->{version}, $params->{info}{$_->{name}}{version});
	    if ($cmp_version > 0 ||
		$cmp_version == 0 && version_compare($_->{release}, $params->{info}{$_->{name}}{release}) > 0) {
		$params->{info}{$_->{name}} = $_;
		++$relocated_entries;
	    }
	}
    }

    if ($relocated_entries) {
	for (0 .. scalar(@{$params->{depslist}}) - 1) {
	    my $pkg = $params->{depslist}[$_];
	    $pkg->{source} and next; #- hack to avoid losing local package.
	    $params->{depslist}[$_] = $params->{info}{$pkg->{name}};
	}
    }

    $relocated_entries;
}

#- write depslist.ordered file according to info in params.
sub write_depslist {
    my ($params, $FILE, $min, $max) = @_;

    $min > 0 or $min = 0;
    defined $max && $max < scalar(@{$params->{depslist} || []}) or $max = scalar(@{$params->{depslist} || []}) - 1;
    $max >= $min or return;

    for ($min..$max) {
	my $pkg = $params->{depslist}[$_];
	printf $FILE "%s-%s-%s %s %s\n", $pkg->{name}, $pkg->{version}, $pkg->{release}, $pkg->{size}, $pkg->{deps};
    }
    1;
}

#- fill params provides with files that can be used, it use the format for
#- a provides file.
sub read_provides_files {
    my ($params, $FILE) = @_;

    local $_;
    while (<$FILE>) {
	chomp;
	my ($k, @v) = split ':';
	$k =~ /^\// and $params->{provides}{$k} ||= undef;
    }
    1;
}

#- check if there has been a problem with reading hdlists or rpms
#- to resolve provides on files.
#- this is done by checking whether there exists a keys in provides
#- hash where to value is null (and the key is a file).
#- give the result as output.
sub get_unresolved_provides_files {
    my ($params) = @_;
    my ($k, $v, @unresolved);

    while (($k, $v) = each %{$params->{provides}}) {
	$k =~ /^\// && ! defined $v and push @unresolved, $k;
    }
    @unresolved;
}

#- clean everything on provides but keep the files key entry on undef.
#- this is necessary to try a second pass.
sub keep_only_cleaned_provides_files {
    my ($params) = @_;

    foreach (keys %{$params->{provides}}) {
	delete $params->{provides}{$_};
	/^\// and $params->{provides}{$_} = undef;
    }

    #- clean everything else at this point.
    $params->{info} = {};
    $params->{depslist} = [];
}

#- reset params to allow other entries.
sub clean {
    my ($params) = @_;

    $params->{info} = {};
    $params->{depslist} = [];
    $params->{provides} = {};
}

#- read provides, first is key, after values.
sub read_provides {
    my ($params, $FILE) = @_;

    local $_;
    while (<$FILE>) {
	chomp;
	my ($k, @v) = split ':';
	$params->{provides}{$k} = @v > 0 ? \@v : undef;
    }
}

#- write provides, first is key, after values.
sub write_provides {
    my ($params, $FILE) = @_;
    my ($k, $v);

    while (($k, $v) = each %{$params->{provides}}) {
	printf $FILE "%s\n", join ':', $k, @{$v || []};
    }
}

#- read compss, look at DrakX for more info.
sub read_compss {
    my ($params, $FILE) = @_;
    my $p;

    local $_;
    while (<$FILE>) {
	/^\s*$/ || /^#/ and next;
	s/#.*//;

	if (/^(\S.*)/) {
	    $p = $1;
	} else {
	    /(\S+)/;
	    $params->{info}{$1} and $params->{info}{$1}{group} = $p;
	}
    }
    1;
}

#- write compss.
sub write_compss {
    my ($params, $FILE) = @_;
    my %p;

    foreach (values %{$params->{info}}) {
	$_->{group} or next;
	push @{$p{$_->{group}} ||= []}, $_->{name};
    }
    foreach (sort keys %p) {
	print $FILE $_, "\n";
	foreach (@{$p{$_}}) {
	    print $FILE "\t", $_, "\n";
	}
	print $FILE "\n";
    }
    1;
}

#- compare a version string, make sure no deadlock can occur.
#- try to return always a numerical value.
sub version_compare {
    my ($a, $b) = @_;
    local $_;

    while ($a || $b) {
	my ($sb, $sa) =  map { $1 if $a =~ /^\W*\d/ ? s/^\W*0*(\d+)// : s/^\W*(\D*)// } ($b, $a);
	$_ = length($sa) cmp length($sb) || $sa cmp $sb and return $_ || 0;
	$sa eq '' && $sb eq '' and return $a cmp $b || 0;
    }
    0;
}

#- compability function which should be removed soon, do not use anymore and replace code.
sub get_packages_installed {
    my ($prefix, $packages, $names, $flags) = @_; $flags ||= [ qw(name version release)];
    my $db = db_open($prefix);
    my $count = db_traverse_tag($db, "name", $names, $flags, sub { my ($p) = @_; push @$packages, $p; });
    db_close($db);
    $count;
}
sub get_all_packages_installed {
    my ($prefix, $packages, $flags) = @_; $flags ||= [ qw(name version release)];
    my $db = db_open($prefix);
    my $count = db_traverse($db, $flags, sub { my ($p) = @_; push @$packages, $p; });
    db_close($db);
    $count;
}
1;
