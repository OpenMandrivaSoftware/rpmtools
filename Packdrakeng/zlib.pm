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

##- This package provide functions to use Zlib::Compress instead gzip.

package Packdrakeng::zlib;

use strict;
use warnings;
use Compress::Zlib;

my $gzip_header = pack("C" . Compress::Zlib::MIN_HDR_SIZE, 
    Compress::Zlib::MAGIC1, Compress::Zlib::MAGIC2, 
    Compress::Zlib::Z_DEFLATED(), 0,0,0,0,0,0,  Compress::Zlib::OSCODE);

sub gzip_compress {
    my ($pack, $sourcefh) = @_;
    my ($insize, $outsize) = (0, 0); # aka uncompressed / compressed data length

    # If $sourcefh is not set, this mean we want a flush(), for end_block()
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

1;
