package rpmtools;

use strict;
use vars qw($VERSION @ISA);

require DynaLoader;

@ISA = qw(DynaLoader);
$VERSION = '0.01';

bootstrap rpmtools $VERSION;

#- build an empty params struct that can be used to compute dependancies.
sub new {
    bless {
	   use_base_flag => 0,
	   flags         => [ qw(name version release size arch group requires provides) ],
	   info          => {},
	   depslist      => [],
	   provides      => {},
	  };
}

#- read one or more hdlist files, use packdrake for decompression.
sub read_hdlists {
    my ($params, @hdlists) = @_;

    local *F;
    open F, "packdrake -c ". join (' ', @hdlists) ." |";
    rpmtools::_parse_(fileno *F, $params->{flags}, $params->{info}, $params->{provides});
    close F;
    1;
}

#- read one or more rpm files.
sub read_rpms {
    my ($params, @rpms) = @_;

    foreach (@rpms) {
	rpmtools::_parse_($_, $params->{flags}, $params->{info}, $params->{provides});
    }
    1;
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
    foreach (@info) {
	push @{$params->{provides}{$_->{name}} ||= []}, $_->{name};
    }

    #- search for entries in provides, if such entries are found,
    #- another pass has to be done. TODO.

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
			foreach (split /\s+/, $info->{deps}) {
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
			    push @requires, $_;
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
    @ordered{qw(setup filesystem basesystem)} = (30000, 20000, 10000);

    #- compute base flag, consists of packages which are required without
    #- choices of basesystem and are ALWAYS installed. these packages can
    #- safely be removed from requires of others packages.
    foreach (@{$params->{info}{basesystem}{requires}}) {
	ref $_ or $params->{info}{$_} and $params->{info}{$_}{base} = undef;
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
	my %requires_id;
	my @requires_id;
	foreach (@{$pkg->{requires}}) {
	    if (ref $_) {
		#- all choices are grouped together at the end of requires,
		#- this allow computation of dropable choices.
		my @choices_id;
		my $to_drop;
		foreach (@$_) {
		    my ($id, $base) = $params->{info}{$_} ? ($params->{info}{$_}{id},
							     $params->{use_base_flag} && exists $params->{info}{$_}{base}) : ($_, 0);
		    $to_drop ||= $id == $pkg->{id} || $requires_id{$id} || $base;
		    push @choices_id, $id;
		}
		$to_drop or push @requires_id, \@choices_id;
	    } else {
		my ($id, $base) = $params->{info}{$_} ? ($params->{info}{$_}{id},
							 $params->{use_base_flag} && exists $params->{info}{$_}{base}) : ($_, 0);
		$requires_id{$id} = $_;
		$id == $pkg->{id} or $base or push @requires_id, $id;
	    }
	}
	#- cannot remove requires values as they are necessary for closure on incremental job.
	$pkg->{deps} = join(' ', map { join '|', @{ref $_ ? $_ : [$_]} } @requires_id);
	$pkg->{name} eq 'basesystem' and $params->{use_base_flag} = 1;
	push @{$params->{depslist}}, $pkg;
    }
    1;
}

#- read depslist.ordered file, as if it was computed internally.
sub read_depslist {
    my ($params, $FILE) = @_;
    my $global_id = scalar @{$params->{depslist}};

    foreach (<$FILE>) {
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
	foreach (split /\s+/, $params->{info}{basesystem}{deps}) {
	    /\|/ or push @requires_id, $_;
	}
	foreach (@requires_id) {
	    $params->{depslist}[$_] and $params->{depslist}[$_]{base} = undef;
	}
	$params->{info}{basesystem}{base} = undef; #- make sure.
	$params->{use_base_flag} = 1;
    }
    1;
}

#- write depslist.ordered file according to info in params.
sub write_depslist {
    my ($params, $FILE, $min, $max) = @_;

    foreach (grep { (! defined $min || $_->{id} >= $min) && (! defined $max || $_->{id} <= $max) }
	     sort { $a->{id} <=> $b->{id} } values %{$params->{info}}) {
	printf $FILE "%s-%s-%s %s %s\n", $_->{name}, $_->{version}, $_->{release}, $_->{size}, $_->{deps};
    }
    1;
}

#- fill params provides with files that can be used, it use the format for
#- a provides file.
sub read_provides_files {
    my ($params, $FILE) = @_;

    foreach (<$FILE>) {
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
	/^\// ? $params->{provides}{$_} = undef : delete $params->{provides}{$_};
    }

    #- clean everything else at this point.
    $params->{use_base_flag} = 0;
    $params->{info} = {};
    $params->{depslist} = [];
}

#- read provides, first is key, after values.
sub read_provides {
    my ($params, $FILE) = @_;

    foreach (<$FILE>) {
	chomp;
	my ($k, @v) = split ':';
	$params->{provides}{$k} = \@v;
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

    foreach (<$FILE>) {
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

1;