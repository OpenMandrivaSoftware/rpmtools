##- Nanar <nanardon@mandriva.org>
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
#
# $Id$

package Distribconf::Build;

=head1 NAME

Distribconf::Build - Extension to Distribconf to build configuration

=head1 METHODS

=over 4

=cut

use strict;
use warnings;
use Distribconf;

our @ISA = qw(Distribconf);
our $VERSION = $Distribconf::VERSION;

=item Distribconf::Build->new($root_of_distrib)

Returns a new Distribconf::Build object.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless $self, $class;
}

=item $distrib->setvalue($media, $var, $val)

Sets or adds $var parameter from $media to $val. If $media doesn't exist,
it is implicitly created. If $var is C<undef>, a new media is created with
no defined parameters.

=cut

sub setvalue {
    my ($distrib, $media, $var, $val) = @_;
    if ($var) {
        $var =~ /^(?:media|info)dir\z/ and do {
            $distrib->{$var} = $val;
            return;
        };
        $distrib->{cfg}->newval($media, $var, $val)
	    or die "Can't set value [$var=$val] for $media\n";
    } else {
        $distrib->{cfg}->AddSection($media);
    }
}

=item $distrib->write_hdlists($hdlists)

Writes the F<hdlists> file to C<$hdlists>, or if no parameter is given, in
the media information directory. C<$hdlists> can be a file path or a file
handle. Returns 1 on success, 0 on error.

=cut

sub write_hdlists {
    my ($distrib, $hdlists) = @_;
    my $h_hdlists;
    if (ref $hdlists eq 'GLOB') {
        $h_hdlists = $hdlists;
    } else {
        $hdlists ||= "$distrib->{root}/$distrib->{infodir}/hdlists";
        open $h_hdlists, ">", $hdlists
	    or return 0;
    }
    foreach my $media ($distrib->listmedia) {
        printf($h_hdlists "%s%s\t%s\t%s\t%s\n",
            join('', map { "$_:" } grep { $distrib->getvalue($media, $_) } qw/askmedia suppl noauto/) || "",
            $distrib->getvalue($media, 'hdlist'),
            $distrib->getpath($media, 'path'),
            $distrib->getvalue($media, 'name'),
            $distrib->getvalue($media, 'size') ? '('.$distrib->getvalue($media, 'size'). ')' : "",
        ) or return 0;
    }
    return 1;
}

=item $distrib->write_mediacfg($mediacfg)

Write the media.cfg file into the media information directory, or into the
$mediacfg given as argument. $mediacfg can be a file path, or a glob reference
(\*STDOUT for example).

Returns 1 on success, 0 on error.

=cut

sub write_mediacfg {
    my ($distrib, $hdlistscfg) = @_;
    $hdlistscfg ||= "$distrib->{root}/$distrib->{infodir}/media.cfg";
    $distrib->{cfg}->WriteConfig($hdlistscfg);
}

=item $distrib->write_version($version)

=cut

sub write_version {
    my ($distrib, $version) = @_;
    my $h_version;
    if (ref($version) eq 'GLOB') {
        $h_version = $version;
    } else {
        $version ||= $distrib->getfullpath(undef, 'VERSION');
        open($h_version, ">", $version) or return 0;
    }

    my @gmt = gmtime(time);

    printf($h_version "Mandriva Linux %s %s-%s-%s%s %s\n",
        $distrib->getvalue(undef, 'version') || 'cooker',
        $distrib->getvalue(undef, 'branch') || 'cooker',
        $distrib->getvalue(undef, 'arch') || 'noarch',
        $distrib->getvalue(undef, 'product'),
        $distrib->getvalue(undef, 'tag') ? '-' . $distrib->getvalue(undef, 'tag') : '',
        sprintf("%04d%02d%02d %02d:%02d", $gmt[5] + 1900, $gmt[4]+1, $gmt[3], $gmt[2], $gmt[1])
    );

    if (ref($version) ne 'GLOB') {
        close($h_version);
    }
    return 1;
}


=item $distrib->check($fhout)

Performs basic checks on the distribution and prints to $fhout (STDERR by
default) warnings and errors found. Returns the number of errors reported.

=cut

sub check {
    my ($distrib, $fhout) = @_;
    $fhout ||= \*STDERR;

    my $error = 0;

    my $report_err = sub {
        my ($l, $f, @msg) = @_;
        $l eq 'E' and $error++;
        printf $fhout "$l: $f\n", @msg;
    };

    $distrib->listmedia or $report_err->('W', "No media found in this config");

    # Checking no overlap
    foreach my $var (qw/hdlist synthesis path/) {
        my %e;
        foreach ($distrib->listmedia) {
            my $v = $distrib->getpath($_, $var);
            push @{$e{$v}}, $_;
        }

        foreach my $key (keys %e) {
            if (@{$e{$key}} > 1) {
                $report_err->('E', "media %s have same %s (%s)",
                    join (", ", @{$e{$key}}),
                    $var,
                    $key
                );
            }
        }
    }

    foreach my $media ($distrib->listmedia) {
	-d $distrib->getfullpath($media, 'path') or $report_err->(
	    'E', "dir %s does't exist for media '%s'",
	    $distrib->getpath($media, 'path'),
	    $media
	);
	foreach (qw/hdlist synthesis pubkey/) {
	    -f $distrib->getfullpath($media, $_) or $report_err->(
		'E', "$_ %s doesn't exist for media '%s'",
		$distrib->getpath($media, $_),
		$media
	    );
	}
    }
    return $error;
}

1;

__END__

=back

=head1 SEE ALSO

L<Distribconf>

=cut
