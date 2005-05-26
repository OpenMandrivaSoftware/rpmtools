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
#
# $Id$

package Distribconf::Build;

=head1 NAME

Distribconf::Build - Extend Distribconf module to allow building the conf

=head1 METHODS

=cut

use strict;
use warnings;

use Distribconf;

use vars qw(@ISA);
@ISA = qw(Distribconf);


=head2 new(root_of_distrib)

Return a new Distribconf::Build object

=cut

sub new {
    my ($class, @options) = @_;
    my $self = $class->SUPER::new(@options);

    bless($self, $class);
}

=head2 write_hdlists($hdlists)

Write the hdlists file into the media information directory, or into the
$hdlists given as argument. $hdlists can be a file path, or a glob reference
(\*STDOUT for example).

Return 1 on success, 0 on error.

=cut

=head2 setvalue($media, $var, $val)

Set or add $var parameter from $media to $val.

If $media does not exists, it is implicitly created.
If $var is not defined, a new media is create without parameters defined.

=cut

sub setvalue {
    my ($distrib, $media, $var, $val) = @_;
    if ($var) {
        $var =~ /^mediadir$|^infodir$/ and do {
            $distrib->{$var} = $val;
            return;
        };
        $distrib->{cfg}->newval($media, $var, $val) or die "Can't set value";
    } else {
        $distrib->{cfg}->AddSection($media);
    }
}

sub write_hdlists {
    my ($distrib, $hdlists) = @_;
    my $h_hdlists;
    if (ref($hdlists) eq 'GLOB') {
        $h_hdlists = $hdlists;
    } else {
        $hdlists ||= "$distrib->{root}/$distrib->{infodir}/hdlists";
        open($h_hdlists, ">", $hdlists) or return 0;
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

    if (ref($hdlists) ne 'GLOB') {
        close($h_hdlists);
    }
    return 1;
}

=head2 write_mediacfg($mediacfg)

Write the media.cfg file into the media information directory, or into the
$mediacfg given as argument. $mediacfg can be a file path, or a glob reference
(\*STDOUT for example).

Return 1 on success, 0 on error.

=cut

sub write_mediacfg {
    my ($distrib, $hdlistscfg) = @_;
    $hdlistscfg ||= "$distrib->{root}/$distrib->{infodir}/media.cfg";
    $distrib->{cfg}->WriteConfig($hdlistscfg);
}

=head2 write_version($version)

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

    printf($h_version "Mandrakelinux %s %s-%s-%s%s %s\n",
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


=head2 check($out)

Perform a check on the distribution and print to $out (STDOUT by default)
errors found

=cut

sub check {
    my ($distrib, $out) = @_;
    $out ||= \*STDOUT;

    my $error = 0;

    my $report_err = sub {
        my ($l, $f, @msg) = @_;
        $l eq 'E' and $error++;
        printf $out "$l: $f\n", @msg;
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
                $report_err->('E', "medium %s have same %s (%s)",
                    join (", ", @{$e{$key}}),
                    $var,
                    $key
                );
            }
        }
    }

    foreach my $media ($distrib->listmedia) {
        -d $distrib->getfullpath($media, 'path') or
            $report_err->('E', "dir %s does't exist for media '%s'",
                $distrib->getpath($media, 'path'),
                $media
            );

        foreach (qw/hdlist synthesis pubkey/) {
            -f $distrib->getfullpath($media, $_) or
                $report_err->('E', "$_ %s doesn't exist for media '%s'",
                    $distrib->getpath($media, $_),
                    $media
                );
        }
    }
    return $error;
}

1;

__END__

=head1 SEE ALSO

L<Distribconf>

=head1 AUTHOR

The code has been written by Olivier Thauvin <nanardon@mandrake.org>.

The media.cfg has been improved by Warly <warly@mandrakesoft.com>.

Special thanks to Rafael Garcia-Suarez <rgarciasuarez@mandrakesoft.com> for
suggesting to use Config::IniFiles.

Thanks to Sylvie Terjan <erinmargault@mandrake.org> for the spell checking.

=head1 ChangeLog

    $Log$
    Revision 1.2  2005/05/26 09:32:40  rgarciasuarez
    Fix error messages

    Revision 1.1  2005/02/22 20:12:31  othauvin
    - split Distribconf with Build
    - add write_VERSION

    Revision 1.7  2005/02/22 12:52:51  othauvin
    - don't add a 'm' to size in hdlists

    Revision 1.6  2005/02/21 21:40:10  othauvin
    - add getfullpath
    - s![ /]*!_! in default path
    - add check()

    Revision 1.5  2005/02/21 15:34:56  othauvin
    Distribconf

    Revision 1.4  2005/02/21 13:14:19  othauvin
    - add doc for pubkey

    Revision 1.3  2005/02/21 13:11:01  othauvin
    - lowercase media name in file name
    - manage pubkey

    Revision 1.2  2005/02/21 12:47:34  othauvin
    - avoid error message about non existing media.cfg

    Revision 1.1  2005/02/20 21:15:50  othauvin
    - initials release for managing mandrakelinux distro tree


=cut
