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

##- $Id$

package packdrakeng;

use strict;
use warnings;
use POSIX;
use File::Path;
use File::Temp qw(tempfile);
use Compress::Zlib;
use vars qw($VERSION);

my $debug = 1;
$VERSION = 0.10;

my  ($toc_header, $toc_footer) = 
    ('cz[0',      '0]cz');
my $gzip_header = pack("C" . Compress::Zlib::MIN_HDR_SIZE, 
    Compress::Zlib::MAGIC1, Compress::Zlib::MAGIC2, 
    Compress::Zlib::Z_DEFLATED(), 0,0,0,0,0,0,  Compress::Zlib::OSCODE);
my $gzip_header_len = length($gzip_header);


sub _new {
    my ($class, %options) = @_;

    my $pack = {
        filename => $options{archive},
        
        compress_method => $options{compress},
        uncompress_method => $options{uncompress},
        force_extern => $options{extern} || 0, # Don't use perl-zlib
        use_extern => 1, # default behaviour, informative only
        
        level => $options{comp_level} || 6, # compression level, aka -X gzip or bzip option

        bloc_size => $options{bloc_size} || 400 * 1024, # A compressed bloc will contain 400k of compressed data
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
        current_bloc_files => {}, # Files in pending compressed bloc
        current_bloc_csize => 0,  # Actual size in pending compressed bloc
        current_bloc_coff => 0,   # The bloc bloc location (offset)
        current_bloc_off => 0,    # Actual uncompressed file offset within the pending bloc
        
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
    $pack->{log}->("Creating new archive with '%s' / '%s'%s.",
        $pack->{compress_method}, $pack->{uncompress_method},
        $pack->{use_extern} ? "" : " (internal compression)");
    $pack
}

sub open {
    my ($class, %options) = @_;
    my $pack = _new($class, %options);
    sysopen($pack->{handle}, $pack->{filename}, O_RDONLY) or return undef;
    $pack->read_toc();
    $pack->{log}->("Opening archive with '%s' / '%s'%s.",
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
            $pack->{subcompress} = \&gzip_compress;
            $pack->{subuncompress} = \&gzip_uncompress;
            $pack->{use_extern} = 0;
            $pack->{direct_write} = 1;
        }
    };
    $pack->{uncompress_method} ||= "$pack->{compress_method} -d";
    $pack->{compress_method} = "$pack->{compress_method} -$pack->{level}";
}

sub DESTROY {
    my ($pack) = @_;
    $pack->build_toc();
    close($pack->{handle}) if ($pack->{handle});
}

# Flush current compressed bloc
# Write 
sub build_toc {
    my ($pack) = @_;
    $pack->{need_build_toc} or return 1;
    $pack->end_bloc();
    my ($toc_length, $cf, $cd, $cl) = (0, 0, 0, 0);

    sysseek($pack->{handle}, $pack->{coff}, 0) == $pack->{coff} or return 0;

    foreach my $entry (keys %{$pack->{'dir'}}) {
        $cd++;
        $toc_length += syswrite($pack->{handle}, $entry . "\n");
    }
    foreach my $entry (keys %{$pack->{'symlink'}}) {
        $cl++;
         $toc_length += syswrite($pack->{handle}, sprintf("%s\n%s\n", $entry, $pack->{'symlink'}{$entry}));
    }
    foreach my $entry (sort keys %{$pack->{files}}) {
        $cf++;
        $toc_length += syswrite($pack->{handle}, $entry ."\n");
    }
    foreach my $file (sort keys %{$pack->{files}}) {
        my $entry = $pack->{files}{$file};
        syswrite($pack->{handle}, pack('NNNN', $entry->{coff}, $entry->{csize}, $entry->{off}, $entry->{size})) or return 0;
    }
    syswrite($pack->{handle}, pack("a4NNNNa40a4",
        $toc_header,
        $cd, $cl, $cf,
        $toc_length,
        $pack->{uncompress_method},
        $toc_footer)) or return 0;
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

    #printf STDERR "Toc size: %d + 16 * %d\n", $toc_str_size, $toc_f_count;
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
    my $seekvalue = $pack->{direct_write} ? $pack->{coff} + $pack->{current_bloc_csize} : $pack->{coff};
    sysseek($pack->{handle}, $seekvalue, 0) == $seekvalue
}

#- To terminate a compressed bloc, flush the pending compressed data,
#- fill toc data still unknown
sub end_bloc {
    my ($pack) = @_;
    $pack->end_seek() or return 0;
    my $m = $pack->{subcompress};
    my (undef, $csize) = $pack->$m(undef);
    $pack->{current_bloc_csize} += $csize;
    foreach (keys %{$pack->{current_bloc_files}}) {
        $pack->{files}{$_} = $pack->{current_bloc_files}{$_};
        $pack->{files}{$_}{csize} = $pack->{current_bloc_csize};
    }
    $pack->{coff} += $pack->{current_bloc_csize};
    $pack->{current_bloc_coff} += $pack->{current_bloc_csize};
    $pack->{current_bloc_csize} = 0;
    $pack->{current_bloc_files} = {};
    $pack->{current_bloc_off} = 0;
    
}

#######################
# Compression wrapper #
#######################

sub extern_compress {
    my ($pack, $sourcefh) = @_;
    my ($insize, $outsize, $filesize) = (0, 0, 0); # aka uncompressed / compressed data length
    my ($hin, $hout); # handle for open2
    
    if (defined($pack->{cstream_data})) {
        ($hin, $hout) = ($pack->{cstream_data}{hin}, $pack->{cstream_data}{hout});
        $filesize = (stat($pack->{cstream_data}{file_bloc}))[7];
    }
    if (defined($sourcefh)) {
        if (!defined($pack->{cstream_data})) {
            ($hin, $pack->{cstream_data}{file_bloc}) = tempfile();
            CORE::open($hout, "|$pack->{compress_method} > $pack->{cstream_data}{file_bloc}") or do {
                warn "Unable to start $pack->{compress_method}";
                return 0, 0;
            };
            ($pack->{cstream_data}{hin}, $pack->{cstream_data}{hout}) = ($hin, $hout);
            binmode $hin; binmode $hout;
            $| =1;
        }
        # until we have data to push or data to read
        while (my $length = sysread($sourcefh, my $data, $pack->{bufsize})) {
            # pushing data to compressor
            (my $l = syswrite($hout, $data)) == $length or do {
                warn "can't push all data to compressor";
            };
            $insize += $l;
            $outsize = (stat($pack->{cstream_data}{file_bloc}))[7];
        }
    } elsif (defined($pack->{cstream_data})) {
        # If $sourcefh is not set, this mean we want a flush(), for end_bloc()
        close($hout);
        unlink($pack->{cstream_data}{file_bloc});
        while (my $lenght = sysread($hin, my $data, $pack->{bufsize})) {
            (my $l = syswrite($pack->{handle}, $data)) == $lenght or do {
                warn "Can't write all data in archive";
            };
            $outsize += $l;
        }
        close($hin);
        $pack->{cstream_data} = undef;
    }
    ($insize, $outsize - $filesize)
}

sub extern_uncompress {
    my ($pack, $destfh, $fileinfo) = @_;
    
    # We have to first extract the bloc to a temp file, burk !
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

    CORE::open(my $hc, "$pack->{uncompress_method} < '$tempname' |") or do {
        warn "Can't start $pack->{uncompress_method} to uncompress data";
        unlink($tempname);
        return -1;
    };

    my $byteswritten = 0;
    my $read = 0;

    while ($byteswritten < $fileinfo->{size}) {
        my $length = sysread($hc, my $data, $pack->{bufsize}) or do {
            warn "unexpected end of stream";
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

sub gzip_compress {
    my ($pack, $sourcefh) = @_;
    my ($insize, $outsize) = (0, 0); # aka uncompressed / compressed data length

    # If $sourcefh is not set, this mean we want a flush(), for end_bloc()
    # EOF, flush compress stream, adding crc
    if (!defined($sourcefh)) {
        if (defined($pack->{cstream_data}{object})) {
            my ($cbuf, $status) = $pack->{cstream_data}{object}->flush();
            $outsize += syswrite($pack->{handle}, $cbuf);
            $outsize += syswrite($pack->{handle}, pack("V V", $pack->{cstream_data}{crc}, $pack->{cstream_data}{object}->total_in()));
        }
        $pack->{cstream_data} = undef;
        return(undef, $outsize);
    }
    
    if (!defined $pack->{cstream_data}{object}) {
        # Writing gzip header file
        $outsize += syswrite($pack->{handle}, $gzip_header);
        $pack->{cstream_data}{object} = deflateInit(
                      -Level         => $pack->{level},
                      # Zlib do not create gzip header, except with this flag
                      -WindowBits     =>  - MAX_WBITS(),
                  );
    }
    
    binmode $sourcefh;
    
    while (my $lenght = sysread($sourcefh, my $buf, $pack->{bufsize})) {
        $pack->{cstream_data}{crc} = crc32($buf, $pack->{cstream_data}{crc});
        my ($cbuf, $status) = $pack->{cstream_data}{object}->deflate($buf);
        $outsize += syswrite($pack->{handle}, $cbuf);
        $insize += $lenght;
    }

    ($insize, $outsize)
}

sub gzip_uncompress {
    my ($pack, $destfh, $fileinfo) = @_;
    my $x = inflateInit(
        -WindowBits     =>  - MAX_WBITS(),
    );
    my $cread = 0; # Compressed data read
    {
        my $buf;
        # get magic
        if (sysread($pack->{handle}, $buf, 2) == 2) {
            my @magic = unpack("C*", $buf);
            $magic[0] == Compress::Zlib::MAGIC1 && $magic[1] == Compress::Zlib::MAGIC2 or do {
                warn("Wrong magic header found");
                return -1;
            };
        } else {
            warn("Unexpect end of file while reading magic");
            return -1;
        }
        my ($method, $flags);
        if (sysread($pack->{handle}, $buf, 2) == 2) {
            ($method, $flags) = unpack("C2", $buf);
        } else {
            warn("Unexpect end of file while reading flags");
            return -1;
        }

        if (sysread($pack->{handle}, $buf, 6) != 6) {
            warn("Unexpect end of file while reading gzip header");
            return -1;
        }

        $cread += 12; #Gzip header fixed size is already read
        if ($flags & 0x04) {
            if (sysread($pack->{handle}, $buf, 2) == 2) {
                my $len = unpack("I", $buf);
                $cread += $len;
                if (sysread($pack->{handle}, $buf, $len) != $len) {
                    warn("Unexpect end of file while reading gzip header");
                    return -1;
                }
            } else {
                warn("Unexpect end of file while reading gzip header");
                return -1;
            }
        }
    }
    my $byteswritten = 0;
    my $read = 0; # uncompressed data read
    while ($byteswritten < $fileinfo->{size}) {
        my $cl=sysread($pack->{handle}, my $buf, 
            $cread + $pack->{bufsize} > $fileinfo->{csize} ? 
                $fileinfo->{csize} - $cread : 
                $pack->{bufsize}) or do {
            warn("Enexpected end of file");
            return -1;
        };
        $cread += $cl;
        my ($out, $status) = $x->inflate(\$buf);
        $status == Z_OK || $status == Z_STREAM_END or do {
            warn("Unable to uncompress data");
            return -1;
        };
        my $l = length($out) or next;
        if ($read < $fileinfo->{off} && $read + $l > $fileinfo->{off}) {
            $out = substr($out, $fileinfo->{off} - $read);    
        }
        $read += $l;
        if ($read <= $fileinfo->{off}) { next }
        
        my $bw = $byteswritten + length($out) > $fileinfo->{size} ? $fileinfo->{size} - $byteswritten : length($out);
        syswrite($destfh, $out, $bw) == $bw or do {
            warn "Can't write data into dest";
            return -1;
        };
        $byteswritten += $bw;

    }
    $byteswritten
}

###################
# Debug functions #
###################

# This function extract in $dest the whole bloc containing $file, can be usefull for debugging
sub extract_bloc {
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
# Aka function poeple should use #
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
        $pack->{current_bloc_files}{$filename} = {
            size => $size,
            off => $pack->{current_bloc_off},
            coff => $pack->{current_bloc_coff},
            csize => -1, # Still unknown, will be fill by end_bloc
        }; # Storing in toc structure availlable info
            
        # Updating internal info about current bloc
        $pack->{current_bloc_off} += $size;
        $pack->{current_bloc_csize} += $csize;
        $pack->{need_build_toc} = 1;
        if ($pack->{bloc_size} > 0 && $pack->{current_bloc_csize} >= $pack->{bloc_size}) {
            $pack->end_bloc();
        }
        return 1;
    };
    0
}

sub add {
    my ($pack, $prefix, @files) = @_;
    $prefix ||= ""; $prefix =~ s://+:/:;
    foreach my $file (@files) {
        $file =~ s://+:/:;
        my $srcfile = $prefix ? "$prefix/$file" : $file;
        
        -l $file and do {
            $pack->add_virtual('l', $file, readlink($srcfile));
            next;
        };
        -d $file and do { # dir simple case
            $pack->add_virtual('d', $file);
            next;
        };
        -f $file and do {
            sysopen(my $htocompress, $srcfile, O_RDONLY) or next;
            $pack->add_virtual('f', $file, $htocompress);
            close($htocompress);
            next;
        };
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
    my ($pack, $dir, @file) = @_;
    foreach my $f (@file) {
        my $dest = $dir ? "$dir/$f" : "$f";
        if (exists($pack->{dir}{$f})) {
            -d "$dest" || mkpath("$dest")
                or warn "Unable to create dir $dest";
            next;
        } elsif (exists($pack->{'symlink'}{$f})) {
            symlink("$dest", $pack->{'symlink'}{$f}) 
                or warn "Unable to extract symlink $f";
            next;
        } elsif (exists($pack->{files}{$f})) {
            sysopen(my $destfh, "$dest", O_CREAT | O_TRUNC | O_WRONLY)
                or next;
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
sub dump {
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

packdrakeng - Simple Archive Extractor/Builder

=head1 SYNOPSIS

    use packdrakeng;
    
    # creating an archive
    $pack = packdrakeng->new(archive => "myarchive.cz");
    # Adding few files
    $pack->add("/path/", "file1", "file2");
    # Adding an unamed file
    open($handle, "file");
    $pack->add_virtual("filename", $handle);
    close($handle);

    $pack = undef;
    
    # extracting an archive
    $pack = packdrakeng->open(archive => "myarchive.cz");
    # listing files
    $pack->list();
    # extracting few files
    $pack->extract("/path/", "file1", "file2");
    # extracting data into a file handle
    open($handle, "file");
    $pack->extract_virtual($handle, "filename");
    close($handle);

=head1 DESCRIPTION

C<packdrakeng> is a simple indexed archive builder and extractor using
standard compression method.

This module is a rewrite from scratch of original packdrake, used format is
fully compatible with old packdrake.

=head1 IMPLEMENTATION

Compressed data are stored by bloc:

 UncompresseddatA1UncompresseddatA2 UncompresseddatA3UncompresseddatA4
 |--- size  1 ---||--- size  2 ---| |--- size  3 ---||--- size  4 ---|
 |<-offset1       |<-offset2        |<-offset3       |<-offset4

give:

 CompresseD1CompresseD2 CompresseD3CompresseD4
 |--- c. size 1, 2 ---| |--- c. size 3, 4 ---|
 |<-c. offset 1, 2      |<-c. offset 3, 4

A new bloc is started when its size exceed the C<bloc_size> value.

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

Follow the files sizes, 4 values for each files are stored:
offset into archive of compressed bloc, size of compressed bloc,
offset into bloc of the file and the file's size.

Finally the archive contain a trailer, of 64 bytes length, about the
toc and the archive itself:
'cz[0', strings 4 bytes
number of directory, 4 bytes
number of symlinks, 4 bytes
number of files, 4 bytes
the toc size, 4 bytes
the uncompressed command, strings of 40 bytes length
'0]cz', strings 4 bytes

=head1 FUNCTIONS

=over

=item B<new(%options)>

Create a new archive.
Options:

=over 4 

=item archive

The file name of the archive. If the file don't exists, it is create, else it is owerwritten.
see C<open>.

=item compress

The application to use to compress, if unset, gzip is used.

=item uncompress

The application to use to extract data from archive. This option is useless if
you're opening an existing archive (except you want to force it).
If unset, this value is based on compress command followed by '-d' argument.

=item extern

If you're using gzip, by default packdrakeng use perl-zlib to limit system
coast. This options force packdrakeng to use the extern gzip command. This
has no with other compress programs until internal functions are not implement
yet.

=item comp_level

The compression level passed as argument to the compress program. By default
this is set to 6.

=item bloc_size

The limit size from which we start a new compressed bloc. The default value is
400KB. Setting it to 0 to be sure a new bloc will be started for each packed
files, -1 to never start a new bloc. Be aware a big size of bloc will slower
the file extraction.

=item quiet

Do not ouput anythings, shut up.

=item debug

Print debug messages

=back

=item B<open(%options)>

Open an existing archive for extracting or adding files.

The uncompressed command is found into the archive, the compressed command is
found from it.

In case you add files, an new compressed bloc will be started regardless the
latest bloc is smaller than the bloc_size. All compression options can't be
find in the archive, so new preference will be applied.

Options are same than the C<new()> function.

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
