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
        
        method => $options{method} || "gzip",
        level => $options{comp_level} || 9,

        bloc_size => $options{bloc_size} || 1024*1024, # A compressed bloc will contain 1 Mega of compressed data

        #################
        # Internal data #
        #################
        
        handle => undef, # Archive handle
        
        # Toc information
        files => {}, # filename => { off, size, coff, csize }
        dir => {}, # dir => no matter what value
        'symlink' => {}, # file => link
        
        coff => 0,
        bufsize => $options{bufsize} || 65536, # Arbitrary buffer size to read files

        # Data we need keep in memory to achieve the storage
        current_bloc_files => [], # Files in pending compressed bloc
        current_bloc_csize => 0,  # Actual size in pending compressed bloc
        current_bloc_coff => 0,   # The bloc bloc location (offset)
        current_bloc_off => 0,    # Actual uncompressed file offset within the pending bloc
        
        stream_data => undef,     # Wrapper data we need to keep in memory
    };
    
    bless($pack, $class)
}

sub new {
    my ($class, %options) = @_;
    my $pack = _new($class, %options);
    
    sysopen($pack->{handle}, $pack->{filename}, O_WRONLY | O_TRUNC | O_CREAT) or return undef;
    $pack->{need_build_toc} = 1;
    $pack
}

sub open {
    my ($class, %options) = @_;
    my $pack = _new($class, %options);
    sysopen($pack->{handle}, $pack->{filename}, O_RDONLY) or return undef;
    $pack->read_toc();
    $pack
}

sub DESTROY {
    my ($pack) = @_;
    $pack->build_toc();
    close($pack->{handle}) if ($pack->{handle});
}

sub build_toc {
    my ($pack) = @_;
    $pack->{need_build_toc} or return 1;
    $pack->end_bloc();
    my ($toc_length, $cf, $cd, $cl) = (0, 0, 0, 0);

    my $handle = $pack->{handle};

    foreach my $entry (keys %{$pack->{'dir'}}) {
        $cd++;
        $toc_length += syswrite($handle, $entry . "\n");
    }
    foreach my $entry (keys %{$pack->{'symlink'}}) {
        $cl++;
         $toc_length += syswrite($handle, sprintf("%s\n%s\n", $entry, $pack->{'symlink'}{$entry}));
    }
    foreach my $entry (keys %{$pack->{files}}) {
        $cf++;
        $toc_length += syswrite($handle, $entry ."\n");
    }
    foreach my $file (keys %{$pack->{files}}) {
        my $entry = $pack->{files}{$file};
        syswrite $handle, pack('NNNN', $entry->{coff}, $entry->{csize}, $entry->{off}, $entry->{size});
        #printf(STDERR "%s %d %d %d %d\n", $file, $entry->{coff}, $entry->{csize}, $entry->{off}, $entry->{size});
    }
    syswrite $handle, pack("a4NNNNa40a4",
        $toc_header,
        $cd, $cl, $cf,
        $toc_length,
        $pack->{method} eq 'gzip' ? "gzip -d" : "bzip2 -d",
        $toc_footer);
       
   close($handle);
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

#- To terminate a compressed bloc, flush the pending compressed data,
#- fill toc data still unknown
sub end_bloc {
    my ($pack) = @_;
    my (undef, $csize) = $pack->gzip_compress(undef);
    $pack->{current_bloc_csize} += $csize;
    $pack->{coff} += $csize;
    foreach (@{$pack->{current_bloc_files}}) {
        $pack->{files}{$_}{csize} = $pack->{current_bloc_csize};
    }
    $pack->{current_bloc_coff} += $pack->{current_bloc_csize};
    $pack->{current_bloc_csize} = 0;
    $pack->{current_bloc_files} = [];
    $pack->{current_bloc_off} = 0;
    
}

#######################
# Compression wrapper #
#######################

sub gzip_compress {
    my ($pack, $sourcefh) = @_;
    my ($insize, $outsize) = (0, 0); # aka uncompressed / compressed data length

    # If $sourcefh is not set, this mean we want a flush(), for end_bloc()
    # EOF, flush compress stream, adding crc
    if (!defined($sourcefh)) {
        if (defined($pack->{stream_data}{object})) {
            my ($cbuf, $status) = $pack->{stream_data}{object}->flush();
            $outsize += syswrite($pack->{handle}, $cbuf);
            $outsize += syswrite($pack->{handle}, pack("V V", $pack->{stream_data}{crc}, $pack->{stream_data}{object}->total_in()));
        }
        $pack->{stream_data} = undef;
        return(undef, $outsize);
    }
    
    if (!defined $pack->{stream_data}{object}) {
        # Writing gzip header file
        $outsize += syswrite($pack->{handle}, $gzip_header);
        $pack->{stream_data}{object} = deflateInit(
                      -Level         => $pack->{level},
                      # Zlib do not create gzip header, except with this flag
                      -WindowBits     =>  - MAX_WBITS(),
                  );
    }
    
    binmode $sourcefh;
    
    while (my $lenght = sysread($sourcefh, my $buf, $pack->{bufsize})) {
        $pack->{stream_data}{crc} = crc32($buf, $pack->{stream_data}{crc});
        my ($cbuf, $status) = $pack->{stream_data}{object}->deflate($buf);
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
        my $cl=sysread($pack->{handle}, my $buf, $pack->{bufsize}) or do {
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
        # print STDERR "cr $cread / $fileinfo->{csize} ur $read / $fileinfo->{off}\n";
        if ($read < $fileinfo->{off}) { next }
        if ($byteswritten + $l > $fileinfo->{size}) {
            $byteswritten += syswrite($destfh, $out, $fileinfo->{size} - $byteswritten);
        } else {
            $byteswritten += syswrite($destfh, $out);
        }
    }
    $byteswritten
}

###################
# Dubug functions #
###################

# This function extract in $dest the whole bloc containing $file, can be usefull for debugging
sub extract_bloc {
    my ($pack, $dest, $file) = @_;
    #print STDERR "Extracting block containing file $file\n";

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
        # Be sur we are at the end, allow extract + add in only one instance
        sysseek($pack->{handle}, $pack->{coff}, 0) == $pack->{coff} or do {
            warn("Can't seek to offset $pack->{coff}");
            next;
        };
        push @{$pack->{current_bloc_files}}, $filename;
        my ($size, $csize) = $pack->gzip_compress($data);
        $pack->{coff} += $csize;
        $pack->{files}{$filename} = {
            size => $size,
            off => $pack->{current_bloc_off},
            coff => $pack->{current_bloc_coff},
            csize => -1, # Still unknown, will be fill by end_bloc
        }; # Storing in toc structure availlable info
            
        # Updating internal info about current bloc
        $pack->{current_bloc_off} += $size;
        $pack->{current_bloc_csize} += $csize;
        $pack->{need_build_toc} = 1;
        if ($pack->{current_bloc_csize} >= $pack->{bloc_size}) {
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
        #print STDERR "Adding $file\n";
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
    $pack->gzip_uncompress($destfh, $pack->{files}{$filename});
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
