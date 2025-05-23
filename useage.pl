#!perl -w
############################################################################
#
# offline.pl 
# Written August/September 2005 by Jeff Leggett
#
# This program reads the PLUS DB for agents in offline mode
# Then calculates the # of days a given agent has been offline.  This is 
# compared to an internal database of servers (hermes) to get the ones that
# should be active.
#
# This program has been re-written many times to use many different 
# Interland backend DB (SNITCH, OASIS, OASIS Data Mart, and now hermes).
# Hopefully doesn't require another re-write anytime soon.
#
#############################################################################
use strict;
use Getopt::Std;

sub usage()
{
print STDERR << "EOF";

$0 : A program to find and report on offline servers in patchlink and there 
real status in OASIS.

usage : $0 [-lh]

 -h 	: this (help) output
 -l 	: location - either 'Atlanta' or 'Miami'

example : $0 -l Atlanta

EOF
exit;
}
my $PLSERVER = "";
my %opt;
getopts( 'hl:', \%opt ) or usage();
usage() if $opt{h};


if ($opt{l} eq "Atlanta") {
   $PLSERVER = "patchlink1.interland.net";
}
elsif ($opt{l} eq "Miami") {
   $PLSERVER = "patchlink2.interland.net";
}
else { usage(); }
print "$PLSERVER\n";
exit;
