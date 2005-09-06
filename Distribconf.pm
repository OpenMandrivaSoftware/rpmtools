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

package Distribconf;

=head1 NAME

Distribconf - perl module to get config from a Mandriva Linux distribution tree

=head1 SYNOPSIS

    use Distribconf;

    my $d = Distribconf->new("/path/to/the/distribution/root");
    $d->load() and die "The dir does not seems to be a distribution tree";

    print $d->getpath(undef, "root") ."\n";
    foreach ($d->listmedia) {
        printf "%s -> %s\n", $d->getpath($_, "hdlist"), $d->getpath($_, path);
    }

=head1 DESCRIPTION

Distribconf is a little module to get/write the configuration of a
Mandriva Linux distribution tree.

The goal is to manage both configuration of old-style trees
(C<Mandrake/base/> ie 10.0 and older) and of new-style ones
(C<media/media_info/> ie 10.1 and newer).

Another point about the C<hdlists> file: the format is limited and does not
permit to add new values without breaking compatiblity. This module is able to
find a C<media.cfg> that allows to add new parameters. See the L</media.cfg>
section. To keep compatiblity with old tools, this module is able to generate
an F<hdlists> file based on this C<media.cfg>.

=head1 media.cfg

The media.cfg is like an ini file. All parameters are optional, this means that
a readable empty file is ok, if this is what you want :)

The media.cfg contains sections, each section corresponding to a media, except
the [media_info] section wich is used to store global info. The section name is
the path where the rpms are located. The section name is sufficient to identify
a media.

Some values have specific signification:

=over 4

=item media specific values:

=over 4

=item B<hdlist>

the path or basename of the hdlist, if not specified by default is
hdlist_mediapath.cz, '/' characters are replaced by '_',

=item B<synthesis>

the path or basename of the synthesis, by default is hdlist name
prefixed by 'synthesis',

=item B<pubkey>

the path or basename of the gpg public key file, by default the
the media name prefixed by 'pubkey_',

=item B<name>

the name of the media, by default is media path, '/' character are
replaced by '_',

=back

=item global specific values:

=over 4

=item B<root>

the root of the distribution tree, this value is not set in
media.cfg, can't be owerwritten, is only use internaly

=item B<mediadir>

the default directory from 'root' path where media are
located, automatically found by Distribconf.

=item B<infodir>

the default directory from 'root' path where distrib informations
are located, automatically found by Distribconf.

=back

=back

For section name (path) hdlist and synthesis, if there is only the basename,
the path is relative to the mediadir or infodir, else the path is relative
to the 'root'one :

    - hdlist.cz is root/infodir/hdlist.cz,
    - ./hdlist.cz is root/./hdlist.cz.

The media.cfg should be located at the same location than hdlists,
so Mandrake/base won't happen (this tree form is no longer used)
and media/media_info will.

Let's start, first a very basic (but valid) media.cfg:

    [main]
    [contrib]
    [jpackage]

Simple, isn't it ? :)
Now a more complex but more realistic media.cfg:

    # Comment
    [media_info]
    # if one tools want to use these values
    version=10.2
    branch=cooker

    [main]
    hdlist=hdlist_main.cz
    name=Main
    size=3400m

    [../SRPMS/main]
    hdlist=hdlist_main.src.cz
    name=Main Sources
    noauto=1

    [contrib]
    hdlist=hdlist_contrib.cz
    name=Contrib
    size=4300m

    [../SRPMS/contrib]
    hdlist=hdlist_contrib.src.cz
    name=Contrib Sources
    noauto=1

    [jpackage]
    hdlist=hdlist_jpackage.cz
    name=Jpackage
    size=360m
    noauto=1

    [../SRPMS/jpackage]
    hdlist=hdlist_jpackage.src.cz
    name=Jpackage Sources
    noauto=1

=head1 METHODS

=cut

use strict;
use warnings;

use Config::IniFiles;

=head2 new($root_of_distrib)

Return a new Distribconf object having C<$root_of_distrib> as top level of the
tree.

=cut

sub new {
    my ($class, $path) = @_;

    my $distrib = {
        root => $path,
        medium => {},
        cfg => new Config::IniFiles( -default => 'media_info', -allowcontinue => 1),
    };

    bless($distrib, $class);
}

=head2 load

Find and load the configuration of the distrib:

=over 4

=item find the path where are located information

=item if availlable load media.cfg

=item if availlable load hdlists

=back

Return 0 on success, 1 if no directory containing media information is found,
2 if no media.cfg, neither hdlists are found.

See also L<loadtree>, L<parse_hdlists> and L<parse_mediacfg>.

=cut

sub load {
    my ($distrib) = @_;
    $distrib->loadtree() or return 1;

    $distrib->parse_mediacfg() || $distrib->parse_hdlists() or return 2;

    return 0;
}

=head2 loadtree

Try to find a valid media information directory, on success set infodir
and mediadir.

Return 1 on success, 0 if no media information directory was found.

=cut

sub loadtree {
    my ($distrib) = @_;

    if (-d "$distrib->{root}/media/media_info") {
        $distrib->{infodir} = "media/media_info";
        $distrib->{mediadir} = "media";
    } elsif (-d "$distrib->{root}/Mandrake/base") {
        $distrib->{infodir} = "Mandrake/base";
        $distrib->{mediadir} = "Mandrake";
    } else {
        return 0;
    }
    return 1;
}

=head2 parse_hdlists($hdlists)

Read the hdlists file found in the media information directory of the
distribution, otherwise set the hdlists file given as argument.

Return 1 on success, 0 if hdlists can't be found or is invalid.

=cut

# what to return if hdlists is found but invalid
sub parse_hdlists {
    my ($distrib, $hdlists) = @_;
    $hdlists ||= "$distrib->{root}/$distrib->{infodir}/hdlists";

    open(my $h_hdlists, "<", $hdlists) or return 0;
    $distrib->{cfg} = new Config::IniFiles( -default => 'media_info', -allowcontinue => 1);
    my $i = 0;
    foreach (<$h_hdlists>) {
        s/#.*//;
        chomp;
        length or next;
        my ($options, %media);
        ($options, @media{qw/hdlist path name size/}) =
            $_ =~ m/^\s*(?:(.*):)?(\S+)\s+(\S+)\s+([^(]*)(?:\s+\((\w+)\))?$/;
        if ($options) { $media{$_} = 1 foreach(split(':', $options)) }
        $media{name} =~ s/\s*$//;
        $media{path} =~ s!^$distrib->{mediadir}/+!!;
        foreach (qw/hdlist name size/, $options ? split(':', $options) : ()) {
            $distrib->{cfg}->newval($media{path}, $_, $media{$_}) or die "Can't set value";
        }
    }
    close($h_hdlists);

    return 1;
}

=head2 parse_version($version)

=cut

sub parse_version {
    my ($distrib, $fversion) = @_;
    $fversion ||= $distrib->getfullpath(undef, 'VERSION');
    open(my $h_ver, "<", $fversion) or return 0;
    my $l = <$h_ver>;
    chomp($l);
    my ($version, $branch, $product, $arch) = $l =~ /^(?:mandrake|mandriva) ?linux\s+(\w+)\s+([^- ]*)-([^- ]*)-([^- ]*)/i;
    $distrib->{cfg}->newval('media_info', 'version', $version);
    $distrib->{cfg}->newval('media_info', 'branch', $branch);
    $distrib->{cfg}->newval('media_info', 'product', $product);
    $distrib->{cfg}->newval('media_info', 'arch', $arch);
    close($h_ver);
    return 1;
}

=head2 parse_mediacfg($mediacfg)

Read the media.cfg file found in the media information directory of the
distribution, otherwise set the $mediacfg file given as argument.

Return 1 on success, 0 if media.cfg can't be found or is invalid.

=cut

sub parse_mediacfg {
    my ($distrib, $mediacfg) = @_;
    $mediacfg ||= "$distrib->{root}/$distrib->{infodir}/media.cfg";
    (-f $mediacfg && -r _) &&
        ($distrib->{cfg} = new Config::IniFiles( -file => $mediacfg, -default => 'media_info', -allowcontinue => 1))
            or return 0;
    return 1;
}

=head2 listmedia

Return an array of existing media in the configuration

=cut

sub listmedia {
    my ($distrib) = @_;
    return grep { $_ ne 'media_info' } $distrib->{cfg}->Sections;
}

=head2 getvalue($media, $var)

Return the $var value for $media, return undef if the value is not set.

If $var is name, hdlist or synthesis, and the value is not explicity defined,
the return value is expanded from $media.

If $media is 'media_info' or undef, you'll get the global value.

This function does not take care about path, see L<getpath>.

=cut

sub getvalue {
    my ($distrib, $media, $var) = @_;
    $media ||= 'media_info';

    my $default = "";
    SWITCH: for ($var) {
        /^synthesis$/ and do { $default = 'synthesis.' . lc($distrib->getvalue($media, 'hdlist')); };
        /^hdlist$/    and do { $default = 'hdlist_' . lc($distrib->getvalue($media, 'name')) . '.cz'; };
        /^pubkey$/    and do { $default = 'pubkey_' . lc($distrib->getvalue($media, 'name')); };
        /^name$/      and do { $default = $media; };
        $default =~ s![/ ]+!_!g;
        /^path$/      and return $media;
        /^root$/      and return $distrib->{root};
        /^VERSION$/   and do { $default = 'VERSION'; last; };
        /^product$/   and do { $default = 'Download'; last; };
        /^tag$/   and do { $default = ''; last; };
        /^branch$/   and do { $default = ''; last; };
        /^mediadir$|^infodir$/  and do { $default = $distrib->{$var}; last; };
    }
    return $distrib->{cfg}->val($media, $var, $default);
}

=head2 getpath($media, $var)

Give relative path from the root of the distrib.

This function is usefull to know where are really located files, it take care
of location of medium, the location of index files, and the path set in the
configuration.

=cut

sub getpath {
    my ($distrib, $media, $var) = @_;

    my $val = $distrib->getvalue($media, $var);
    $var =~ /^root$|^VERSION$/ and return $val;
    return ($val =~ m!/! ? "" : ($var eq 'path' ? $distrib->{mediadir} : $distrib->{infodir} ) . "/") . $val;
}

=head2 getfullpath($media, $var)

Does the same thing than L<getpath> but the return value is already
prefixed by the 'root' path.
This function is shortcut for:
$distrib->getpath(undef, 'root') . '/' . $distrib->getpath($media, $var).

=cut

sub getfullpath {
    my ($distrib, $media, $var) = @_;
    return $distrib->getpath(undef, 'root') . '/' . $distrib->getpath($media, $var);
}

1;

__END__

=head1 AUTHOR

The code has been written by Olivier Thauvin <nanardon@mandriva.org>.

The media.cfg has been improved by Warly <warly@mandriva.com>.

Special thanks to Rafael Garcia-Suarez <rgarciasuarez@mandriva.com> for
suggesting to use Config::IniFiles.

Thanks to Sylvie Terjan <erinmargault@mandriva.org> for the spell checking.

=head1 ChangeLog

    $Log$
    Revision 1.10  2005/09/06 19:46:16  othauvin
    - s/mandrake/mandriva/

    Revision 1.9  2005/03/07 13:45:09  rgarciasuarez
    Doc and POD fixes

    Revision 1.8  2005/02/22 20:12:31  othauvin
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
