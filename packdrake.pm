package packdrake;

use strict;
use vars qw($VERSION);

$VERSION = "0.03";

=head1 NAME

packdrake - Mandrake Simple Archive Extractor/Builder

=head1 SYNOPSYS

    require packdrake;

    packdrake::cat_archive("/export/Mandrake/base/hdlist.cz",
                           "/export/Mandrake/base/hdlist2.cz");
    packdrake::list_archive("/tmp/modules.cz2");

    my $packer = new packdrake("/tmp/modules.cz2");
    $packer->extract_archive("/tmp", "file1.o", "file2.o");

    my $packer = packdrake::build_archive
        (\*STDIN, "/lib/modules", "/tmp/modules.cz2",
         400000, "bzip2", "bzip2 -d");
    my $packer = packdrake::build_archive
        (\*STDIN, "/export/Mandrake/base/hdlist.cz",
         400000, "gzip -9", "gzip -d");

=head1 DESCRIPTION

C<packdrake> is a very simple archive extractor and builder used by MandrakeSoft.

=head1 IMPLEMENTATION

uncompressing sheme is:
        | |
        | |                                        | |
 $off1 =|*| }                                      | |
        |*| }                               $off2 =|+| }
        |*| } $siz1   =>   'gzip/bzip2 -d'   =>    |+| } $siz2  => $filename
        |*| }                                      |+| }
        |*| }                                      | |
        | |                                        | |
        | |                                        | |
        | |
where %data has the following format:
  { 'filename' => [ 'f', $off1, $siz1, $off2, $siz2 ] }
except for symbolink link where it is:
  { 'filename_symlink' => [ 'l', $symlink_value ] }
and directory where it is only
  { 'filename_directory' => [ 'd' ] }
as you can see, there is no owner, group, filemode... an extension could be
made with 'F' (instead of 'f'), 'L' instead of 'l' for exemple.
we do not need them as it is used for DrakX for fast archive extraction and
owner/filemode is for user running only (ie root).

archive file contains concatenation of all bzip2'ed group of files whose
filenames are on input,
then a TOC (describing %data, concatenation of toc_line) follow and a
TOC_TRAILER for summary.

=head1 SEE ALSO

packdrake command is a simple executable perl script using this module.

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

#- taken from DrakX common stuff, for conveniance and modified to match our expectation.
sub dirname { @_ == 1 or die "packdrake: usage: dirname <name>\n"; local $_ = shift; s|[^/]*/*\s*$||; s|(.)/*$|$1|; $_ || '.' }
sub basename { @_ == 1 or die "packdrake: usage: basename <name>\n"; local $_ = shift; s|/*\s*$||; s|.*/||; $_ }
sub mkdir_ {
    my $root = dirname $_[0];
    if (-e $root) {
	-d $root or die "packdrake: mkdir: error creating directory $_[0]: $root is a file and i won't delete it\n";
    } else {
	mkdir_($root);
    }
    -d $_[0] and return;
    mkdir $_[0], 0755 or die "packdrake: mkdir: error creating directory $_: $!\n";
}
sub symlink_ { mkdir_ dirname($_[1]); unlink $_[1]; symlink $_[0], $_[1] }

#- for building an archive, returns the string containing the file and data associated.
sub build_toc_line {
    my ($file, $data) = @_;

    for ($data->[0]) {
	return(/l/ && pack("anna*", 'l', length($file), length($data->[1]), "$file$data->[1]") ||
	       /d/ && pack("ana*", 'd', length($file), $file) ||
	       /f/ && pack("anNNNNa*", 'f', length($file), @{$data}[1..4], $file) ||
	       die "packdrake: unknown extension $_\n");
    }
}

sub build_toc_trailer {
    my ($packer) = @_;

    #- 'cz[0' is toc_trailer header where 0 is version information, only 0 now.
    #- '0]cz' is toc_trailer trailer that match the corresponding header for information.
    pack "a4NNNNa40a4", ($packer->{header},
			 $packer->{toc_d_count}, $packer->{toc_l_count}, $packer->{toc_f_count},
			 $packer->{toc_str_size}, $packer->{uncompress},
			 $packer->{trailer});
}

#- degraded reading of toc at end of archive, do not check filelist.
sub read_toc_trailer {
    my ($packer, $file) = @_;
    my $toc_trailer;

    local *ARCHIVE;
    open ARCHIVE, "<$file" or die "packdrake: cannot open archive file $file\n";
    $packer->{archive} = $file;

    #- seek to end of file minus 64, size of trailer.
    #- read toc_trailer, check header/trailer for version 0.
    seek ARCHIVE, -64, 2;
    read ARCHIVE, $toc_trailer, 64 or die "packdrake: cannot read toc_trailer of archive file $file\n";
    @{$packer}{qw(header toc_d_count toc_l_count toc_f_count toc_str_size uncompress trailer)} =
      unpack "a4NNNNZ40a4", $toc_trailer;
    $packer->{header} eq 'cz[0' && $packer->{trailer} eq '0]cz' or die "packdrake: bad toc_trailer in archive file $file\n";

    close ARCHIVE;
}

#- read toc at end of archive.
sub read_toc {
    my ($packer, $file) = @_;
    my ($toc, $toc_trailer, $toc_size);
    my @toc_str;
    my @toc_data;

    local *ARCHIVE;
    open ARCHIVE, "<$file" or die "packdrake: cannot open archive file $file\n";
    $packer->{archive} = $file;

    #- seek to end of file minus 64, size of trailer.
    #- read toc_trailer, check header/trailer for version 0.
    seek ARCHIVE, -64, 2;
    read ARCHIVE, $toc_trailer, 64 or die "packdrake: cannot read toc_trailer of archive file $file\n";
    @{$packer}{qw(header toc_d_count toc_l_count toc_f_count toc_str_size uncompress trailer)} =
      unpack "a4NNNNZ40a4", $toc_trailer;
    $packer->{header} eq 'cz[0' && $packer->{trailer} eq '0]cz' or die "packdrake: bad toc_trailer in archive file $file\n";

    #- read toc, extract data hashes.
    $toc_size = $packer->{toc_str_size} + 16*$packer->{toc_f_count};
    seek ARCHIVE, -64-$toc_size, 2;

    #- read strings separated by \n, so this char cannot be inside filename, oops.
    read ARCHIVE, $toc, $packer->{toc_str_size} or die "packdrake: cannot read toc of archive file $file\n";
    @toc_str = split "\n", $toc;

    #- read data for file.
    read ARCHIVE, $toc, 16*$packer->{toc_f_count} or die "packdrake: cannot read toc of archive file $file\n";
    @toc_data = unpack "N". 4*$packer->{toc_f_count}, $toc;

    close ARCHIVE;

    foreach (0..$packer->{toc_d_count}-1) {
	my $file = $toc_str[$_];
	push @{$packer->{files}}, $file;
	$packer->{data}{$file} = [ 'd' ];
    }
    foreach (0..$packer->{toc_l_count}-1) {
	my ($file, $symlink) = ($toc_str[$packer->{toc_d_count}+2*$_],
				$toc_str[$packer->{toc_d_count}+2*$_+1]);
	push @{$packer->{files}}, $file;
	$packer->{data}{$file} = [ 'l', $symlink ];
    }
    foreach (0..$packer->{toc_f_count}-1) {
	my $file = $toc_str[$packer->{toc_d_count}+2*$packer->{toc_l_count}+$_];
	push @{$packer->{files}}, $file;
	$packer->{data}{$file} = [ 'f', @toc_data[4*$_ .. 4*$_+3] ];
    }

    scalar keys %{$packer->{data}} == $packer->{toc_d_count}+$packer->{toc_l_count}+$packer->{toc_f_count} or
      die "packdrake: mismatch count when reading toc, bad archive file $file\n";
}

sub catsksz {
    my ($input, $seek, $siz, $output) = @_;
    my ($buf, $sz);

    while (($sz = sysread($input, $buf, $seek > 65536 ? 65536 : $seek))) {
	$seek -= $sz;
	last unless $seek > 0;
    }
    while (($sz = sysread($input, $buf, $siz > 65536 ? 65536 : $siz))) {
	$siz -= $sz;
	syswrite($output, $buf);
	last unless $siz > 0;
    }
}

sub cat_compress {
    my ($packer, $srcdir, @filenames) = @_;
    local *F;
    open F, "| $ENV{LD_LOADER} $packer->{compress} >$packer->{tmpz}"
      or die "packdrake: cannot start \"$packer->{compress}\"\n";
    foreach (@filenames) {
 	my $srcfile = $srcdir ? "$srcdir/$_" : $_;
	my ($buf, $siz, $sz);
	local *FILE;
	open FILE, $srcfile or die "packdrake: cannot open $srcfile: $!\n";
	$siz = -s $srcfile;
	while (($sz = sysread(FILE, $buf, $siz > 65536 ? 65536 : $siz))) {
	    $siz -= $sz;
	    syswrite(F, $buf);
	    last unless $siz > 0;
	}
	close FILE;
    }
    close F;
    -s $packer->{tmpz};
}

#- compute the closure of filename list according to symlinks or directory
#- contents inside the archive.
sub compute_closure {
    my $packer = shift;
    my %file;
    my @file;

    #- keep in mind when a filename already exist and remove doublons.
    @file{@_} = ();

    #- navigate through filename list to follow symlinks.
    do {
	@file = grep { !$file{$_} } keys %file;
	foreach (@file) {
	    my $file = $_;

	    #- keep in mind this one has been processed and does not need
	    #- to be examined again.
	    $file{$file} = 1;

	    exists $packer->{data}{$file} or next;

	    for ($packer->{data}{$file}[0]) {
		#- on symlink, try to follow it and mark %file if
		#- it is still inside the archive contents.
		/l/ && do {
		    my ($source, $target) = ($file, $packer->{data}{$file}[1]);

		    $source =~ s|[^/]*$||; #- remove filename to navigate directory.
		    if ($source) {
			while ($target =~ s|^\./|| || $target =~ s|//+|/| || $target =~ s|/$|| or
			       $source and $target =~ s|^\.\./|| and $source =~ s|[^/]*/$||) {}
		    }

		    #- FALL THROUGH with new selection.
		    $file = $target =~ m|^/| ? $target : $source.$target;
		};

		#- on directory, try all files on data starting with
		#- this directory, provided they are not already taken
		#- into account.
		/[ld]/ && do {
		    @file{grep { !$file{$_} && m|^$file$| || m|^$file/| } keys %{$packer->{data}}} = ();
		    last;
		};
	    }
	}
    } while (@file > 0);

    keys %file;
}


#- getting an packer object.
sub new {
    my ($class, $file) = @_;
    my $packer = bless {
			#- toc trailer data information.
			header       => 'cz[0',
			toc_d_count  => 0,
			toc_l_count  => 0,
			toc_f_count  => 0,
			toc_str_size => 0,
			uncompress   => 'gzip -d',
			trailer      => '0]cz',

			#- tempories used for making an archive.
			tmpz         => ($ENV{TMPDIR} || "/tmp") . "/packdrake-tmp.$$",
			compress     => 'gzip',

			#- internal data to handle compression or uncompression.
			archive      => undef,
			files        => [],
			data         => {},
		       }, $class;
    $file and $packer->read_toc($file);
    $packer;
}

sub cat_archive {
    my $pid;

    foreach (@_)  {
	my $packer = new packdrake;

	#- update %data according to TOC_TRAILER of each archive.
	$packer->read_toc_trailer($_);

	#- dump all the file according to 
	if (my $pid = fork()) {
	    waitpid $pid, 0;
	} else {
	    open STDIN, "<$_" or die "packdrake: unable to open archive $_\n";
	    open STDERR, ">/dev/null" or die "packdrake: unable to open /dev/null\n";

	    exec (($ENV{LD_LOADER} ? ($ENV{LD_LOADER}) : ()), split " ", $packer->{uncompress});

	    die "packdrake: unable to cat the archive with $packer->{uncompress}\n";
	}
    }
}

sub list_archive {
    foreach (@_) {
	my $packer = new packdrake($_);
	my $count = scalar keys %{$packer->{data}};

	print STDERR "processing archive \"$_\"\n";
	print "$count files in archive, uncompression method is \"$packer->{uncompress}\"\n";
	foreach my $file (@{$packer->{files}}) {
	    for ($packer->{data}{$file}[0]) {
		/l/ && do { printf "l %13c %s -> %s\n", ' ', $file, $packer->{data}{$file}[1]; last; };
		/d/ && do { printf "d %13c %s\n", ' ', $file; last; };
		/f/ && do { printf "f %12d %s\n", $packer->{data}{$file}[4], $file; last; };
	    }
	}
    }
}

sub extract_archive {
    my ($packer, $dir, @file) = @_;
    my %extract_table;

    #- compute closure.
    @file = $packer->compute_closure(@file);

    foreach my $file (@file) {
	#- check for presence of file, but do not abort, continue with others.
	$packer->{data}{$file} or do { print STDERR "packdrake: unable to find file $file in archive $packer->{archive}\n"; next };

	my $newfile = "$dir/$file";

	print STDERR "extracting $file\n";
	for ($packer->{data}{$file}[0]) {
	    /l/ && do { symlink_ $packer->{data}{$file}[1], $newfile; last; };
	    /d/ && do { mkdir_ $newfile; last; };
	    /f/ && do {	mkdir_ dirname $newfile;
			my $data = $packer->{data}{$file};
			$extract_table{$data->[1]} ||= [ $data->[2], [] ];
			push @{$extract_table{$data->[1]}[1]}, [ $newfile, $data->[3], $data->[4] ];
			$extract_table{$data->[1]}[0] == $data->[2] or die "packdrake: mismatched relocation in toc\n";
			last;
		    };
	    die "packdrake: unknown extension \"$_\" when uncompressing archive $packer->{archive}\n";
	}
    }

    #- delayed extraction is done on each block for a single  execution
    #- of uncompress executable.
    foreach (sort { $a <=> $b } keys %extract_table) {
	local *OUTPUT;
	if (open OUTPUT, "-|") {
	    #- $curr_off is used to handle the reading in a pipe and simulating
	    #- a seek on it as done by catsksz, so last file position is
	    #- last byte not read (ie last block read start + last block read size).
	    my $curr_off = 0;
	    foreach (sort { $a->[1] <=> $b->[1] } @{$extract_table{$_}[1]}) {
		my ($newfile, $off, $siz) = @$_;
		local *FILE;
		open FILE, $dir ? ">$newfile" : ">&STDOUT";
		catsksz(\*OUTPUT, $off - $curr_off, $siz, \*FILE);
		$curr_off = $off + $siz;
	    }
	    close FILE;
	} else {
	    local *BUNZIP2;
	    open BUNZIP2, "| $ENV{LD_LOADER} $packer->{uncompress}";
	    local *ARCHIVE;
	    open ARCHIVE, "<$packer->{archive}" or die "packdrake: cannot open archive $packer->{archive}\n";
	    catsksz(\*ARCHIVE, $_, $extract_table{$_}[0], \*BUNZIP2);
	    exec 'true'; #- exit ala _exit
	}
    }
}

sub build_archive {
    my ($f, $srcdir, $archivename, $maxsiz, $compress, $uncompress, $tmpz) = @_;
    my ($off1, $siz1, $off2, $siz2) = ('', '', 0, 0, 0, 0);
    my @filelist = ();
    my $packer = new packdrake;

    $packer->{archive} = $archivename;
    $compress && $uncompress and ($packer->{compress}, $packer->{uncompress}) = ($compress, $uncompress);
    $tmpz and $packer->{tmpz} = $tmpz;

    print STDERR "choosing compression method with \"$packer->{compress}\" for archive $packer->{archive}\n";

    unlink $packer->{archive};
    unlink $packer->{tmpz};

    my $file;
    while ($file = <$f>) {
	chomp $file;
	my $srcfile = $srcdir ? "$srcdir/$file" : $file;
	-e $srcfile or die "packdrake: unable to find file $srcfile\n";

	push @{$packer->{files}}, $file;
	#- now symbolic link and directory are supported, extension is
	#- available with the first field of $data{$file}.
	if (-l $file) {
	    $packer->{data}{$file} = [ 'l', readlink $srcfile ];
	} elsif (-d $file) {
	    $packer->{data}{$file} = [ 'd' ];
	} else {
	    $siz2 = -s $srcfile;

	    push @filelist, $file;
	    $packer->{data}{$file} = [ 'f', -1, -1, $off2, $siz2 ];

	    if ($off2 + $siz2 > $maxsiz) { #- need compression.
		$siz1 = cat_compress($packer, $srcdir, @filelist);

		foreach (@filelist) {
		    $packer->{data}{$_} = [ 'f', $off1, $siz1, $packer->{data}{$_}[3], $packer->{data}{$_}[4] ];
		}

		system "$ENV{LD_LOADER} cat '$packer->{tmpz}' >>'$packer->{archive}'";
		$off1 += $siz1;
		$off2 = 0; $siz2 = 0;
		@filelist = ();
	    }
	    $off2 += $siz2;
	}
    }
    if (scalar @filelist) {
	$siz1 = cat_compress($packer, $srcdir, @filelist);

	foreach (@filelist) {
	    $packer->{data}{$_} = [ 'f', $off1, $siz1, $packer->{data}{$_}[3], $packer->{data}{$_}[4] ];
	}

	system "$ENV{LD_LOADER} cat '$packer->{tmpz}' >>'$packer->{archive}'";
	$off1 += $siz1;
    }
    print STDERR "real archive size of $packer->{archive} is $off1\n";

    #- produce a TOC directly at the end of the file, follow with
    #- a trailer with TOC summary and archive summary.
    local *OUTPUT;
    open OUTPUT, ">>$packer->{archive}";

    my ($toc_str, $toc_data) = ('', '');
    my @data_d = ();
    my @data_l = ();
    my @data_f = ();

    foreach my $file (@{$packer->{files}}) {
	$packer->{data}{$file} or die "packdrake: internal error on $_\n";

	#- specific according to type.
	#- with this version, only f has specific data other than strings.
	for ($packer->{data}{$file}[0]) {
	    /d/ && do { push @data_d, $file; last; };
	    /l/ && do { push @data_l, $file; last; };
	    /f/ && do { push @data_f, $file; $toc_data .= pack("NNNN", @{$packer->{data}{$file}}[1..4]); last; };
	    die "packdrake: unknown extension $_\n";
	}
    }

    foreach (@data_d) { $toc_str .= $_ . "\n" }
    foreach (@data_l) { $toc_str .= $_ . "\n" . $packer->{data}{$_}[1] . "\n" }
    foreach (@data_f) { $toc_str .= $_ . "\n" }

    @{$packer}{qw(toc_d_count toc_l_count toc_f_count toc_str_size uncompress)} =
      (scalar(@data_d), scalar(@data_l), scalar(@data_f), length($toc_str), $uncompress);

    print OUTPUT $toc_str;
    print OUTPUT $toc_data;
    print OUTPUT build_toc_trailer($packer);
    close OUTPUT;

    unlink $packer->{tmpz};

    $packer;
}

1;
