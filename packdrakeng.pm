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
use IO::File;
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
        filename => $options{dest},
        handle => undef,
        files => {}, # filename => { off, size, coff, csize }
        dir => {}, # dir => no matter what value
        'symlink' => {}, # file => link
        method => $options{method} || "gzip",
        level => $options{comp_level} || 9,
        off => 0,
        coff => 0,
        bufsize => $options{bufsize} || 65536,
        
    };
    
    bless($pack, $class)
}

sub new {
    my ($class, %options) = @_;
    my $pack = _new($class, %options);
    
    sysopen($pack->{handle}, $pack->{filename}, O_WRONLY | O_TRUNC | O_CREAT);
    $pack->{need_build_toc} = 1;
    $pack
}

sub open {
    my ($class, %options) = @_;
    my $pack = _new($class, %options);
    sysopen($pack->{handle}, $pack->{filename}, O_RDONLY);
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
        printf(STDERR "%s %d %d %d %d\n", $file, $entry->{coff}, $entry->{csize}, $entry->{off}, $entry->{size});
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
        die "Error reading toc: wrong header/trailer";
        return 0;
    };

    printf STDERR "Toc size: %d + 16 * %d\n", $toc_str_size, $toc_f_count;
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
    }
    1
}

#######################
# Compression wrapper #
#######################

sub gzip_compress {
    my ($pack, $sourcefh) = @_;
    my ($insize, $outsize) = (0, 0);
    my $crc = undef;

    binmode $sourcefh;
    # Writing gzip header file
    $outsize += syswrite($pack->{handle}, $gzip_header);
    
    my $x = deflateInit(
                      -Level         => $pack->{level},
                      # Zlib do not create gzip header, except with this flag
                      -WindowBits     =>  - MAX_WBITS(),
                  );

    while (my $lenght = sysread($sourcefh, my $buf, $pack->{bufsize})) {
        $crc = crc32($buf, $crc);
        my ($cbuf, $status) = $x->deflate($buf);
        $outsize += syswrite($pack->{handle}, $cbuf);
        $insize += $lenght;
    }
    # EOF, flush compress stream, adding crc
    {
        my ($cbuf, $status) = $x->flush();
        $outsize += syswrite($pack->{handle}, $cbuf);
        $outsize += syswrite($pack->{handle}, pack("V V", $crc, $x->total_in()));
    }

    ($insize, $outsize)    
}

sub gzip_uncompress {
    my ($pack, $destfh, $fileinfo) = @_;
    printf(STDERR "uncompress file %d %d %d %d\n", $fileinfo->{size},
        $fileinfo->{off}, $fileinfo->{csize}, $fileinfo->{coff});
    print STDERR "Moving to offset $fileinfo->{coff}\n";
    sysseek($pack->{handle}, $fileinfo->{coff}, 0) == $fileinfo->{coff} or do {
        warn("Can't seek to offset $fileinfo->{coff}");
        return -1;
    };
    my $x = inflateInit(
        -WindowBits     =>  - MAX_WBITS(),
    );
    my $cread = 0; # Compressed data read
    {
        my $buf;
    # get magic
        if (sysread($pack->{handle}, $buf, 2) == 2) {
            my @magic = unpack("C*", $buf);
            printf(STDERR "%x %x != %x %x\n", @magic ,Compress::Zlib::MAGIC1, Compress::Zlib::MAGIC2);
            $magic[0] == Compress::Zlib::MAGIC1 && $magic[1] == Compress::Zlib::MAGIC2 or do {
                warn("Wrong magic found");
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
    my $read = 0;
    while ($byteswritten < $fileinfo->{size}) {
        my $l=sysread($pack->{handle}, my $buf, $pack->{bufsize});
        # or do {
        #    warn "Not enought bytes read";
        #    return -1;
        #};
        $cread += $l;
        my ($out, $status) = $x->inflate(\$buf);
        #$status == Z_OK || $status == Z_STREAM_END or return -1;
        if ($read < $fileinfo->{off} && $read + $l > $fileinfo->{off}) {
            $out = substr($out, $fileinfo->{off} - $read);    
        }
        $read += $l;
        if ($read < $fileinfo->{off}) { next }
        if ($byteswritten + length($out) > $fileinfo->{size}) {
            $byteswritten += syswrite($destfh, $out, $fileinfo->{size} - $byteswritten);
        } else {
            $byteswritten += syswrite($destfh, $out);
        }
    }
    $byteswritten
}

############################
# Really working functions #
############################

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
        my $finfo = {
            off => $pack->{off}, coff => $pack->{coff},
            size => 0, csize => 0,
        };
        ($finfo->{size}, $finfo->{csize}) = $pack->gzip_compress($data);
        $pack->{coff} += $finfo->{csize};
        $pack->{off} += $finfo->{size};
        $finfo->{off} = 0; # Allways 0 with this method
        $pack->{files}{$filename} = $finfo;
        $pack->{need_build_toc} = 1;
        return 1;
    };
    0
}

sub add {
    my ($pack, @files) = @_;
    foreach my $file (@files) {
        print STDERR "Adding $file\n";
        -l $file and do {
            $pack->add_virtual('l', $file, readlink($file));
            next;
        };
        -d $file and do { # dir simple case
            $pack->add_virtual('d', $file);
            next;
        };
        -f $file and do {
            sysopen(my $htocompress, $file, O_RDONLY) or next;
            $pack->add_virtual('f', $file, $htocompress);
            close($htocompress);
            next;
        };
    }
}

sub extract_files {
    my ($pack, $dir, @file) = @_;
    foreach my $f (@file) {
        if (exists($pack->{dir}{$f})) {
            -d "$dir/$f" or mkpath("$dir/$f");
            next;
        } elsif (exists($pack->{'symlink'}{$f})) {
            symlink("$dir/$f", $pack->{'symlink'}{$f});
        } elsif (exists($pack->{files}{$f})) {
            sysopen(my $destfh, "$dir/$f", O_CREAT | O_TRUNC | O_WRONLY);
            my $written = $pack->gzip_uncompress($destfh, $pack->{files}{$f});
            printf(STDERR "Writen size for %s: %d / %d\n", $f, $written, $pack->{files}{$f}{size}) if ($debug);
            close($destfh);
            
        }
    }
}

sub list {
    my ($pack) = @_;
    foreach my $file (keys %{$pack->{dir}}) {
        printf "d %13c %s\n", ' ', $file;
    }
    foreach my $file (keys %{$pack->{'symlink'}}) {
        printf "l %13c %s -> %s\n", ' ', $file, $pack->{'symlink'}{$file};
    }
    foreach my $file (keys %{$pack->{files}}) {
        printf "f %12d %s\n", $pack->{files}{$file}{size}, $file;
    }
}

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
