package Packdrakeng;

(our $VERSION) = q($Id$) =~ /(\d+\.\d+)/;

use MDV::Packdrakeng;

*Packdrakeng:: = *MDV::Packdrakeng::;
warn "Warning: Packdrakeng is deprecated, use MDV::Packdrakeng instead.\n";
1;

=head1 NAME

Packdrakeng - Compatibility wrapper around MDV::Packdrakeng

=head1 DESCRIPTION

Don't use this module. Use MDV::Packdrakeng instead.

=cut
