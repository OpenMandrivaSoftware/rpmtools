##- Nanar <nanardon@mandrake.org>
##-
##- This program is free software; you can redistribute it and/or modify
##- it under the terms of the GNU General Public License as published by
##- the Free Software Foundation; either version 2, or (at your option)
##- any later version.
##-
##- This program is distributed in the hope that it will be useful,
##- but WITHOUT ANY WARRANTY; without even the implied warranty of
##- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##- GNU General Public License for more details.
##-
##- You should have received a copy of the GNU General Public License
##- along with this program; if not, write to the Free Software
##- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

package Packdrakeng;

use strict;
use warnings;
use POSIX qw(O_WRONLY O_TRUNC O_CREAT O_RDONLY);
use File::Path;
use File::Temp qw(tempfile);

(our $VERSION) = q$Id$ =~ /(\d+\.\d+)/;

my  ($toc_header, $toc_footer) = 
    ('cz[0',      '0]cz');


sub _new {
    my ($class, %options) = @_;

    my $pack = {
        filename => $options{archive},
        
        compress_method => $options{compress},
        uncompress_method => $options{uncompress},
        force_extern => $options{extern} || 0, # Don't use perl-zlib
        use_extern => 1, # default behaviour, informative only
        noargs => $options{noargs},
        
        level => $options{comp_level} || 6, # compression level, aka -X gzip or bzip option

        block_size => $options{block_size} || 400 * 1024, # A compressed block will contain 400k of compressed data
        bufsize => $options{bufsize} || 65536, # Arbitrary buffer size to read files

        # Internal data
        handle => undef, # Archive handle
        
        # Toc information
        files => {}, # filename => { off, size, coff, csize }
        dir => {}, # dir => no matter what value
        'symlink' => {}, # file => link
        
        coff => 0, # end of current compressed data

        # Compression sub
        subcompress => \&extern_compress,
        subuncompress => \&extern_uncompress,
        direct_write => 0, # Define if wrapper write directly in archive and not into temp file

        # Data we need keep in memory to achieve the storage
        current_block_files => {}, # Files in pending compressed block
        current_block_csize => 0,  # Actual size in pending compressed block
        current_block_coff => 0,   # The block block location (offset)
        current_block_off => 0,    # Actual uncompressed file offset within the pending block
        
        cstream_data => undef,     # Wrapper data we need to keep in memory (compression)
        ustream_data => undef,     # Wrapper data we need to keep in memory (uncompression)

        # log and verbose function:
        log => $options{quiet} ? sub {} : sub { my @w = @_; $w[0] .= "\n"; printf STDERR @w },
        debug => $options{debug} ? sub { my @w =@_; $w[0] = "Debug: $w[0]\n"; printf STDERR @w } : sub {}, 
    };
    
    bless($pack, $class)
}

sub new {
    my ($class, %options) = @_;
    my $pack = _new($class, %options);
    sysopen($pack->{handle}, $pack->{filename}, O_WRONLY | O_TRUNC | O_CREAT) or return undef;
    $pack->choose_compression_method();
    $pack->{need_build_toc} = 1;
    $pack->{debug}->("Creating new archive with '%s' / '%s'%s.",
        $pack->{compress_method}, $pack->{uncompress_method},
        $pack->{use_extern} ? "" : " (internal compression)");
    $pack
}

sub open {
    my ($class, %options) = @_;
    my $pack = _new($class, %options);
    sysopen($pack->{handle}, $pack->{filename}, O_RDONLY) or return undef;
    $pack->read_toc() or return undef;
    $pack->{debug}->("Opening archive with '%s' / '%s'%s.",
        $pack->{compress_method}, $pack->{uncompress_method},
        $pack->{use_extern} ? "" : " (internal compression)");
    $pack
}

# look $pack->{(un)compressed_method} and setup functions/commands to use
# Have some facility about detecting we want gzip/bzip
sub choose_compression_method {
    my ($pack) = @_;

    (!defined($pack->{compress_method}) && !defined($pack->{uncompress_method})) 
        and $pack->{compress_method} = "gzip";
    my $test_method = $pack->{compress_method} || $pack->{uncompress_method};
    
    $test_method =~ m/^bzip2|^bunzip2/ and do {
        $pack->{compress_method} ||= "bzip2";
    };
    $test_method =~ m/^gzip|^gunzip/ and do {
        $pack->{compress_method} ||= "gzip";
        if (!$pack->{force_extern}) {
            eval { require Packdrakeng::zlib; };
            if (! $@) {
                $pack->{subcompress} = \&Packdrakeng::zlib::gzip_compress;
                $pack->{subuncompress} = \&Packdrakeng::zlib::gzip_uncompress;
                $pack->{use_extern} = 0;
                $pack->{direct_write} = 1;
            }
        }
    };
    if (!$pack->{noargs}) {
        $pack->{uncompress_method} ||= "$pack->{compress_method} -d";
        $pack->{compress_method} = $pack->{compress_method} ? "$pack->{compress_method} -$pack->{level}" : "";
    }
}

sub DESTROY {
    my ($pack) = @_;
    $pack->build_toc();
    close($pack->{handle}) if ($pack->{handle});
}

# Flush current compressed block
# Write 
sub build_toc {
    my ($pack) = @_;
    $pack->{need_build_toc} or return 1;
    $pack->end_block();
    $pack->end_seek() or do {
		warn "Can't seek into archive";
		return 0;
	};
    my ($toc_length, $cf, $cd, $cl) = (0, 0, 0, 0);

    foreach my $entry (keys %{$pack->{'dir'}}) {
        $cd++;
		my $w = syswrite($pack->{handle}, $entry . "\n") or do {
			warn "Can't write toc into archive";
			return 0;
		};
        $toc_length += $w; 
    }
    foreach my $entry (keys %{$pack->{'symlink'}}) {
        $cl++;
		my $w = syswrite($pack->{handle}, sprintf("%s\n%s\n", $entry, $pack->{'symlink'}{$entry})) or do {
			warn "Can't write toc into archive";
			return 0;
		};
        $toc_length += $w
	}
    foreach my $entry (sort keys %{$pack->{files}}) {
        $cf++;
		my $w = syswrite($pack->{handle}, $entry ."\n") or do {
			warn "Can't write toc into archive";
			return 0;
		};
        $toc_length += $w;
    }
    foreach my $file (sort keys %{$pack->{files}}) {
        my $entry = $pack->{files}{$file};
        syswrite($pack->{handle}, pack('NNNN', $entry->{coff}, $entry->{csize}, $entry->{off}, $entry->{size})) or do {
			warn "Can't write toc into archive";
			return 0;
		};
    }
    syswrite($pack->{handle}, pack("a4NNNNa40a4",
        $toc_header,
        $cd, $cl, $cf,
        $toc_length,
        $pack->{uncompress_method},
        $toc_footer)) or do {
		warn "Can't write toc into archive";
		return 0;
	};
   1
}

sub read_toc {
    my ($pack) = @_;
    sysseek($pack->{handle}, -64, 2) ; #or return 0;
    sysread($pack->{handle}, my $buf, 64);# == 64 or return 0;
    my ($header, $toc_d_count, $toc_l_count, $toc_f_count, $toc_str_size, $uncompress, $trailer) =
        unpack("a4NNNNZ40a4", $buf);
    $header eq $toc_header && $trailer eq $toc_footer or do {
        warn "Error reading toc: wrong header/trailer";
        return 0;
    };

    $pack->{uncompress_method} ||= $uncompress;
    $pack->choose_compression_method();

    sysseek($pack->{handle}, -64 - ($toc_str_size + 16 * $toc_f_count) ,2); 
    sysread($pack->{handle}, my $fileslist, $toc_str_size);
    my @filenames = split("\n", $fileslist);
    sysread($pack->{handle}, my $sizes_offsets, 16 * $toc_f_count);
    my @size_offset = unpack("N" . 4*$toc_f_count, $sizes_offsets);

    foreach (1 .. $toc_d_count) {
        $pack->{dir}{shift(@filenames)} = 1;
    }
    foreach (1 .. $toc_l_count) {
        my $n = shift(@filenames);
        $pack->{'symlink'}{$n} = shift(@filenames);
    }

    foreach (1 .. $toc_f_count) {
        my $f = shift(@filenames);
        $pack->{files}{$f}{coff} = shift(@size_offset);
        $pack->{files}{$f}{csize} = shift(@size_offset);
        $pack->{files}{$f}{off} = shift(@size_offset);
        $pack->{files}{$f}{size} = shift(@size_offset);
        # looking for offset for this archive
        $pack->{files}{$f}{coff} + $pack->{files}{$f}{csize} > $pack->{coff} and
            $pack->{coff} = $pack->{files}{$f}{coff} + $pack->{files}{$f}{csize};
        }
    1
}

# Goto to the end of written compressed data
sub end_seek {
    my ($pack) = @_;
    my $seekvalue = $pack->{direct_write} ? $pack->{coff} + $pack->{current_block_csize} : $pack->{coff};
    sysseek($pack->{handle}, $seekvalue, 0) == $seekvalue
}

#- To terminate a compressed block, flush the pending compressed data,
#- fill toc data still unknown
sub end_block {
    my ($pack) = @_;
    $pack->end_seek() or return 0;
    my $m = $pack->{subcompress};
    my (undef, $csize) = $pack->$m(undef);
    $pack->{current_block_csize} += $csize;
    foreach (keys %{$pack->{current_block_files}}) {
        $pack->{files}{$_} = $pack->{current_block_files}{$_};
        $pack->{files}{$_}{csize} = $pack->{current_block_csize};
    }
    $pack->{coff} += $pack->{current_block_csize};
    $pack->{current_block_coff} += $pack->{current_block_csize};
    $pack->{current_block_csize} = 0;
    $pack->{current_block_files} = {};
    $pack->{current_block_off} = 0;
}

#######################
# Compression wrapper #
#######################

sub extern_compress {
    my ($pack, $sourcefh) = @_;
    my ($insize, $outsize, $filesize) = (0, 0, 0); # aka uncompressed / compressed data length
    my $hout; # handle for gzip
    
    if (defined($pack->{cstream_data})) {
        $hout = $pack->{cstream_data}{hout};
        $filesize = (stat($pack->{cstream_data}{file_block}))[7];
    }
    if (defined($sourcefh)) {
        if (!defined($pack->{cstream_data})) {
            my $hin;
            ($hin, $pack->{cstream_data}{file_block}) = tempfile();
            close($hin); # ensure the flush
            $pack->{cstream_data}{pid} = CORE::open($hout, 
                "|$pack->{compress_method} > $pack->{cstream_data}{file_block}") or do {
                warn "Unable to start $pack->{compress_method}";
                return 0, 0;
            };
            $pack->{cstream_data}{hout} = $hout;
            binmode $hout;
        }
        # until we have data to push or data to read
        while (my $length = sysread($sourcefh, my $data, $pack->{bufsize})) {
            # pushing data to compressor
            (my $l = syswrite($hout, $data)) == $length or do {
                warn "can't push all data to compressor";
            };
            $insize += $l;
            $outsize = (stat($pack->{cstream_data}{file_block}))[7];
        }
    } elsif (defined($pack->{cstream_data})) {
        # If $sourcefh is not set, this mean we want a flush(), for end_block()
        close($hout);
        waitpid $pack->{cstream_data}{pid}, 0;
        sysopen(my $hin, $pack->{cstream_data}{file_block}, O_RDONLY) or do {
            warn "Can't open temp block file";
            return 0, 0;
        };
        $outsize = (stat($pack->{cstream_data}{file_block}))[7];
        unlink($pack->{cstream_data}{file_block});
        while (my $lenght = sysread($hin, my $data, $pack->{bufsize})) {
            (my $l = syswrite($pack->{handle}, $data)) == $lenght or do {
                warn "Can't write all data in archive";
            };
        }
        close($hin);
        $pack->{cstream_data} = undef;
    }
    ($insize, $outsize - $pack->{current_block_csize})
}

sub extern_uncompress {
    my ($pack, $destfh, $fileinfo) = @_;
    
    # We have to first extract the block to a temp file, burk !
    my ($tempfh, $tempname) = tempfile();

    my $cread = 0;
    while ($cread < $fileinfo->{csize}) {
        my $cl = sysread($pack->{handle}, my $data,
            $cread + $pack->{bufsize} > $fileinfo->{csize} ?
                $fileinfo->{csize} - $cread : 
                $pack->{bufsize}) or do {
                warn("Enexpected end of file");
                close($tempfh);
                unlink($tempname);
                return -1;
        };
        $cread += $cl;
        syswrite($tempfh, $data) == length($data) or do {
            warn "Can't write all data into temp file";
            close($tempfh);
            unlink($tempname);
            return -1;
        };
    }
    close($tempfh);

    CORE::open(my $hc, "cat '$tempname' | $pack->{uncompress_method} |") or do {
        warn "Can't start $pack->{uncompress_method} to uncompress data";
        unlink($tempname);
        return -1;
    };
    binmode($hc);

    my $byteswritten = 0;
    my $read = 0;

    while ($byteswritten < $fileinfo->{size}) {
        my $length = sysread($hc, my $data, $pack->{bufsize}) or do {
            warn "unexpected end of stream $tempname";
            #unlink($tempname);
            close($hc);
            return -1;
        };
        
        
        if ($read < $fileinfo->{off} && $read + $length > $fileinfo->{off}) {
            $data = substr($data, $fileinfo->{off} - $read);
        }
        $read += $length;
        if ($read <= $fileinfo->{off}) { next }
        
        my $bw = $byteswritten + length($data) > $fileinfo->{size} ? $fileinfo->{size} - $byteswritten : length($data);
        syswrite($destfh, $data, $bw) == $bw or do {
            warn "Can't write data into dest";
            return -1;
        };
        $byteswritten += $bw;
    }
    
    close($hc);
    unlink($tempname); # deleting temp file
    $byteswritten

}

###################
# Debug functions #
###################

# This function extract in $dest the whole block containing $file, can be usefull for debugging
sub extract_block {
    my ($pack, $dest, $file) = @_;

    sysopen(my $handle, $dest, O_WRONLY | O_TRUNC | O_CREAT) or do {
        warn "Can't open $dest";
        return -1;
    };
    
    sysseek($pack->{handle}, $pack->{files}{$file}->{coff}, 0) == $pack->{files}{$file}->{coff} or do {
        warn("Can't seek to offset $pack->{files}{$file}->{coff}");
        close($handle);
        return -1;
    };

    {
    my $l;
    $l = sysread($pack->{handle}, my $buf, $pack->{files}{$file}->{csize}) == $pack->{files}{$file}->{csize} or warn "Read only $l / $pack->{files}{$file}->{csize} bytes";
    syswrite($handle, $buf);
    }

    foreach (sort {
            $pack->{files}{$a}{coff} == $pack->{files}{$b}{coff} ?
            $pack->{files}{$a}{off} <=> $pack->{files}{$b}{off} :
            $pack->{files}{$a}{coff} <=> $pack->{files}{$b}{coff} 
        } keys %{$pack->{files}}) {
        $pack->{files}{$_}{coff} == $pack->{files}{$file}->{coff} or next;
    }
    
    close($handle);
    
}

##################################
# Really working functions       #
# Aka function people should use #
##################################

sub add_virtual {
    my ($pack, $type, $filename, $data) = @_;
    $type eq 'l' and do {
        $pack->{'symlink'}{$filename} = $data;
        $pack->{need_build_toc} = 1;
        return 1;
    };
    $type eq 'd' and do {
        $pack->{dir}{$filename}++;
        $pack->{need_build_toc} = 1;
        return 1;
    };
    $type eq 'f' and do {
        # Be sure we are at the end, allow extract + add in only one instance
        $pack->end_seek() or do {
            warn("Can't seek to offset $pack->{coff}");
            next;
        };
        
        my $m = $pack->{subcompress};
        my ($size, $csize) = $pack->$m($data);
        $pack->{current_block_files}{$filename} = {
            size => $size,
            off => $pack->{current_block_off},
            coff => $pack->{current_block_coff},
            csize => -1, # Still unknown, will be fill by end_block
        }; # Storing in toc structure availlable info
            
        # Updating internal info about current block
        $pack->{current_block_off} += $size;
        $pack->{current_block_csize} += $csize;
        $pack->{need_build_toc} = 1;
        if ($pack->{block_size} > 0 && $pack->{current_block_csize} >= $pack->{block_size}) {
            $pack->end_block();
        }
        return 1;
    };
    0
}

sub add {
    my ($pack, $prefix, @files) = @_;
    $prefix ||= "";
    foreach my $file (@files) {
        $file =~ s://+:/:;
        my $srcfile = $prefix ? "$prefix/$file" : $file;
        $pack->{debug}->("Adding '%s' as '%s' into archive", $srcfile, $file);
        
        -l $srcfile and do {
            $pack->add_virtual('l', $file, readlink($srcfile));
            next;
        };
        -d $srcfile and do { # dir simple case
            $pack->add_virtual('d', $file);
            next;
        };
        -f $srcfile and do {
            sysopen(my $htocompress, $srcfile, O_RDONLY) or do {
                warn "Can't add $srcfile: $!";
                next;
            };
            $pack->add_virtual('f', $file, $htocompress);
            close($htocompress);
            next;
        };
        warn "Can't pack $srcfile"; 
    }
    1
}

sub extract_virtual {
    my ($pack, $destfh, $filename) = @_;
    defined($pack->{files}{$filename}) or return -1;
    sysseek($pack->{handle}, $pack->{files}{$filename}->{coff}, 0) == $pack->{files}{$filename}->{coff} or do {
        warn("Can't seek to offset $pack->{files}{$filename}->{coff}");
        return -1;
    };
    my $m = $pack->{subuncompress};
    $pack->$m($destfh, $pack->{files}{$filename});
}

sub extract {
    my ($pack, $destdir, @file) = @_;
    foreach my $f (@file) {
        my $dest = $destdir ? "$destdir/$f" : "$f";
        my ($dir) = $dest =~ m!(.*)/.*!;
		if (exists($pack->{dir}{$f})) {
            -d $dest || mkpath($dest)
                or warn "Unable to create dir $dest: $!";
            next;
        } elsif (exists($pack->{'symlink'}{$f})) {
			-d $dir || mkpath($dir) or
				warn "Unable to create dir $dest: $!";
            -l $dest and unlink $dest;
            symlink($pack->{'symlink'}{$f}, $dest)
                or warn "Unable to extract symlink $f: $!";
            next;
        } elsif (exists($pack->{files}{$f})) {
			-d $dir || mkpath($dir) or do {
				warn "Unable to create dir $dir";
			};
            if (-l $dest) {
                unlink($dest) or do {
                    warn "Can't remove link $dest: $!";
                    next; # Don't overwrite a file because where the symlink point to
                };
            }
            sysopen(my $destfh, $dest, O_CREAT | O_TRUNC | O_WRONLY)
                or do {
				warn "Unable to extract $dest";
				next;
			};
            my $written = $pack->extract_virtual($destfh, $f);
            $written == -1 and warn "Unable to extract file $f";
            close($destfh);
            next;
        } else {
            warn "Can't find $f in archive";
        }
    }
    1
}

# Return \@dir, \@files, \@symlink list
sub getcontent {
    my ($pack) = @_;
    return([ keys(%{$pack->{dir}})], [ keys(%{$pack->{files}}) ], [ keys(%{$pack->{'symlink'}}) ]);
}

sub list {
    my ($pack) = @_;
    foreach my $file (keys %{$pack->{dir}}) {
        printf "d %13c %s\n", ' ', $file;
    }
    foreach my $file (keys %{$pack->{'symlink'}}) {
        printf "l %13c %s -> %s\n", ' ', $file, $pack->{'symlink'}{$file};
    }
    foreach my $file (sort {
            $pack->{files}{$a}{coff} == $pack->{files}{$b}{coff} ?
            $pack->{files}{$a}{off} <=> $pack->{files}{$b}{off} :
            $pack->{files}{$a}{coff} <=> $pack->{files}{$b}{coff} 
        } keys %{$pack->{files}}) {
        printf "f %12d %s\n", $pack->{files}{$file}{size}, $file;
    }
}

# Print toc info
sub dumptoc {
    my ($pack) = @_;
        foreach my $file (keys %{$pack->{dir}}) {
        printf "d %13c %s\n", ' ', $file;
    }
    foreach my $file (keys %{$pack->{'symlink'}}) {
        printf "l %13c %s -> %s\n", ' ', $file, $pack->{'symlink'}{$file};
    }
    foreach my $file (sort {
            $pack->{files}{$a}{coff} == $pack->{files}{$b}{coff} ?
            $pack->{files}{$a}{off} <=> $pack->{files}{$b}{off} :
            $pack->{files}{$a}{coff} <=> $pack->{files}{$b}{coff} 
        } keys %{$pack->{files}}) {
        printf "f %d %d %d %d %s\n", $pack->{files}{$file}{size}, $pack->{files}{$file}{off}, $pack->{files}{$file}{csize}, $pack->{files}{$file}{coff}, $file;
    }
}

1

__END__

=head1 NAME

Packdrakeng - Simple Archive Extractor/Builder

=head1 SYNOPSIS

    use Packdrakeng;
    
    # creating an archive
    $pack = Packdrakeng->new(archive => "myarchive.cz");
    # Adding a few files
    $pack->add("/path/", "file1", "file2");
    # Adding an unamed file
    open($handle, "file");
    $pack->add_virtual("filename", $handle);
    close($handle);

    $pack = undef;
    
    # extracting an archive
    $pack = Packdrakeng->open(archive => "myarchive.cz");
    # listing files
    $pack->list();
    # extracting few files
    $pack->extract("/path/", "file1", "file2");
    # extracting data into a file handle
    open($handle, "file");
    $pack->extract_virtual($handle, "filename");
    close($handle);

=head1 DESCRIPTION

C<Packdrakeng> is a simple indexed archive builder and extractor using
standard compression methods.

This module is a from scratch rewrite of the original packdrake. Its format is
fully compatible with old packdrake.

=head1 IMPLEMENTATION

Compressed data are stored by block. For example,

 UncompresseddatA1UncompresseddatA2 UncompresseddatA3UncompresseddatA4
 |--- size  1 ---||--- size  2 ---| |--- size  3 ---||--- size  4 ---|
 |<-offset1       |<-offset2        |<-offset3       |<-offset4

gives:

 CompresseD1CompresseD2 CompresseD3CompresseD4
 |--- c. size 1, 2 ---| |--- c. size 3, 4 ---|
 |<-c. offset 1, 2      |<-c. offset 3, 4

A new block is started when its size exceeds the C<block_size> value.

Compressed data are followed by the toc, ie a simple list of packed files.
Each file name is terminated by the "\n" character:

    dir1
    dir2
    ...
    dirN
    symlink1
    point_file1
    symlink2
    point_file2
    ...
    ...
    symlinkN
    point_fileN
    file1
    file2
    ...
    fileN

The file sizes follows, 4 values are stored for each file:
offset into archive of compressed block, size of compressed block,
offset into block of the file and the file's size.

Finally the archive contains a 64-byte trailer, about the
toc and the archive itself:

    'cz[0', strings 4 bytes
    number of directory, 4 bytes
    number of symlinks, 4 bytes
    number of files, 4 bytes
    the toc size, 4 bytes
    the uncompression command, string of 40 bytes length
    '0]cz', string 4 bytes

=head1 FUNCTIONS

=over 2

=item B<new(%options)>

Creates a new archive.
Options:

=over 4 

=item archive

The file name of the archive. If the file doesn't exist, it will be created,
else it will be owerwritten. See C<open>.

=item compress

The application to use to compress, if unspecified, gzip is used.

=item uncompress

The application used to extract data from archive. This option is useless if
you're opening an existing archive (unless you want to force it).
If unset, this value is based on compress command followed by '-d' argument.

=item extern

If you're using gzip, by default Packdrakeng will use perl-zlib to save system
ressources. This option forces Packdrakeng to use the external gzip command. This
has no meaning with other compress programs as internal functions are not implemented
yet.

=item comp_level

The compression level passed as an argument to the compression program. By default,
this is set to 6.

=item block_size

The limit size after which we start a new compressed block. The default value
is 400KB. Set it to 0 to be sure a new block will be started for each packed
files, and -1 to never start a new block. Be aware that a big block size will
slow down the file extraction.

=item quiet

Do not output anything, shut up.

=item debug

Print debug messages.

=back

=item B<open(%options)>

Opens an existing archive for extracting or adding files.

The uncompression command is found into the archive, and the compression
command is deduced from it.

If you add files, a new compressed block will be started even if the
last block is smaller than C<block_size>. If some compression options can't be
found in the archive, the new preference will be applied.

Options are same than the C<new()> function.

=back

=head1 AUTHOR

Olivier Thauvin <nanardon@mandrake.org>

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of GNU General Public License as
published by the Free Software Foundation; either version 2 of
the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

If you do not have a copy of the GNU General Public License write to
the Free Software Foundation, Inc., 675 Mass Ave, Cambridge,
MA 02139, USA.

=cut
