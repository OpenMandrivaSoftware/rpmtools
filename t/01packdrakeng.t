#!/usr/bin/perl

# $Id$

use strict;
use Test::More tests => 21;
use Digest::MD5;

use_ok('Packdrakeng');

sub clean_test_files {
    -d "test" or return;
    unlink glob("test/*");
}

# 
sub create_test_files {
    my ($number) = @_;
    my %created;
    -d "test" or mkdir "test";
    foreach my $n (1 .. $number||10) {
        my $size = int(rand(1024));
        # push(@created, "test/$size");
        system("dd if=/dev/urandom of=test/$size bs=1024 count=$size >/dev/null 2>&1");
        open(my $h, "test/$size");
        $created{"test/$size"} = Digest::MD5->new->addfile($h)->hexdigest;
        close $h;
    }
    %created 
}

sub create_know_files {
    my %created;
    foreach my $letter ('a' .. 'z') {
    open(my $h, "> test/$letter");
    foreach (1 .. 3456) {
        printf $h "%s\n", $letter x 33;
    }
    close($h);
    open($h, "test/$letter");
    $created{"test/$letter"} = Digest::MD5->new->addfile($h)->hexdigest;
    close($h);
    }
    %created
}

sub check_files {
    my %files = @_;
    my $ok = 1;
    foreach my $f (keys %files) {
        open(my $h, $f);
        Digest::MD5->new->addfile($h)->hexdigest ne $files{$f} and do {
            print STDERR "$f differ\n";
            $ok = 0;
        };
        close $h;
    }
    $ok
}

###################################
#                                 #
# Test series, packing, unpacking #
#                                 #
###################################

sub test_packing {
    my ($pack_param, $listfiles) = @_;

    ok(my $pack = Packdrakeng->new(%$pack_param), "Creating an archive");
    $pack or return;
    ok($pack->add(undef, keys %$listfiles), "packing files");
    $pack = undef; # closing the archive.
    
    clean_test_files();
    
    ok($pack = Packdrakeng->open(%$pack_param), "Re-opening the archive");
    $pack or die;
    ok($pack->extract(undef, keys(%$listfiles)), "extracting files");
    ok(check_files(%$listfiles), "Checking md5sum for extracted files");

    $pack = undef;
}

print "Test: using external cat function:\n";
    clean_test_files();
    test_packing({ archive => "packtest-cat.cz", compress => 'cat', uncompress => 'cat', noargs => 1 }, { create_test_files(30) });
    clean_test_files();

print "Test: using internal gzip function:\n";
    clean_test_files();
    test_packing({ archive => "packtest-gzipi.cz" }, { create_test_files(30) });
    clean_test_files();

print "Test: using external gzip function:\n";
    clean_test_files();
    test_packing({ archive => "packtest-gzip.cz", compress => "gzip", extern => 1}, { create_test_files(30) });
    clean_test_files();
   
print "Test: using external bzip function:\n";
    clean_test_files();
    test_packing({ archive => "packtest-bzip2.cz", compress => "bzip2", extern => 1}, { create_test_files(30) });
    clean_test_files();
