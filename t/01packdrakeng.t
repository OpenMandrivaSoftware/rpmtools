#!/usr/bin/perl

# $Id$

use strict;
use Test::More tests => 37;
use Digest::MD5;

use_ok('Packdrakeng');

-d "test" || mkdir "test" or die "Can't create directory test";

my $coin = q{
 ___________
< Coin coin >
 -----------
 \     ,~~.
  \ __( o  )
    `--'==( ___/)
       ( (   . /
        \ '-' /
    ~'`~'`~'`~'`~
};

sub clean_test_files {
    -d "test" or return;
    system("rm -fr $_") foreach (glob("test/*"));
}

sub create_test_files {
    my ($number) = @_;
    my %created;
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

# Testing simple additionnal function:
clean_test_files();

{
my ($handle, $filename) = Packdrakeng::tempfile();
ok($handle && $filename, "can create temp file");
ok(-f $filename, "Temp file exists");
ok(print($handle $coin), "can write into file");
close($handle);
unlink($filename);

ok(Packdrakeng::mkpath('test/parent/child'), "can create dir like mkdir -p");
ok(-d 'test/parent/child', "the dir really exists");
}

# Single test:
{
clean_test_files();

ok(my $pack = Packdrakeng->new(archive => "packtest.cz"), "Create a new archive");
open(my $fh, "+> test/test") or die "Can't open test file $!";
syswrite($fh, $coin);
sysseek($fh, 0, 0);
ok($pack->add_virtual('f', "coin", $fh), "Adding data from file");
close($fh);
unlink("test/test");

ok($pack->add_virtual('d', "dir"), "Adding a dir");
ok($pack->add_virtual('l', "symlink", "dest"), "Adding a symlink");
$pack = undef;

ok($pack = Packdrakeng->open(archive => "packtest.cz"), "Opening the archive");
ok($pack->extract("test", "dir"), "Extracting dir");
ok(-d "test/dir", "dir successfully restored");
ok($pack->extract("test", "symlink"), "Extracting symlink");
ok(readlink("test/symlink") eq "dest", "symlink successfully restored");

open($fh, "+> test/test") or die "Can't open file $!";
ok($pack->extract_virtual($fh, "coin"), "Extracting data");
sysseek($fh, 0, 0);
sysread($fh, my $data, 1000);
close($fh);
ok($data eq $coin, "Data is correct");

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
