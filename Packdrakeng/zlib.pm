package Packdrakeng::zlib;

(our $VERSION) = q($Id$) =~ /(\d+\.\d+)/;

use MDV::Packdrakeng::zlib;

*Packdrakeng::zlib:: = *MDV::Packdrakeng::zlib::;
warn "Warning: Packdrakeng::zlib is deprecated, use MDV::Packdrakeng::zlib instead.\n";
1;

=head1 NAME

Packdrakeng::zlib - Compatibility wrapper around MDV::Packdrakeng::zlib

=head1 DESCRIPTION

Don't use this module. Use MDV::Packdrakeng::zlib instead.

=cut
