package Distribconf::Build;

use Distribconf;
use MDV::Distribconf::Build;

our $VERSION = $Distribconf::VERSION;

*Distribconf::Build:: = *MDV::Distribconf::Build::;
warn "Warning: Distribconf::Build is deprecated, use MDV::Distribconf::Build instead.\n";
1;

=head1 NAME

Distribconf::Build - Compatibility wrapper around MDV::Distribconf::Build

=head1 DESCRIPTION

Don't use this module. Use MDV::Distribconf::Build instead.

=cut
