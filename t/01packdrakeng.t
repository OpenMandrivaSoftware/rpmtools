#!/usr/bin/perl

# $Id$

use Test::More tests => 8;
use Digest::MD5;

use_ok('packdrakeng');

sub clean_random_files {
    -d "test" or return;
    unlink glob("test/*");
}

# 
sub create_random_files {
    my ($number) = @_;
    my %created;
    -d test or mkdir test;
    foreach my $n (1 .. $number||10) {
        my $size = int(rand(1024));
        push(@created, "test/$size");
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
        Digest::MD5->new->addfile($h)->hexdigest ne $files{$f} and $ok = 0;
        close $h;
    }
    $ok
}


# Test: creating
clean_random_files();
my %createdfiles = create_random_files(50);

ok(my $pack = packdrakeng->new(archive => "packtest.cz"), "Creating an archive");
ok($pack->add(undef, keys %createdfiles), "Adding files to the archive");
$pack = undef; # closing the archive.

clean_random_files();
ok($pack = packdrakeng->open(archive => "packtest.cz"), "Re-opening the archive");
$pack->dump;

# Test: all files are packed
my (undef, $packedfiles, undef) = $pack->getcontent();
ok(@$packedfiles > 0, "Archive contains files");

{
my %fex = %createdfiles;
foreach (@$packedfiles) {
    delete $fex{$_}; 
}
ok(! keys(%fex), "All files has been packed");
}

ok($pack->extract(undef, keys(%createdfiles)), "extracting files");
ok(check_files(%createdfiles), "Checking md5sum for extracted files");

