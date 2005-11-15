package Distribconf;

(our $VERSION) = q$Id$ =~ /(\d+\.\d+)/;

use MDV::Distribconf;

*Distribconf:: = *MDV::Distribconf::;
warn "Warning: Distribconf is deprecated, use MDV::Distribconf instead.\n";
1;

=head1 NAME

Distribconf - Compatibility wrapper around MDV::Distribconf

=head1 DESCRIPTION

Don't use this module. Use MDV::Distribconf instead.

=cut
