#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  dateparse.pl
#
#        USAGE:  ./dateparse.pl 
#
#  DESCRIPTION:  Parse out date from filename
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:   (), <>
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  11/03/2006 01:07:33 PM EST
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

my @MISSINGFILES = (
"/etrade/adm/etadm/web/logs/cyota/realtime/wire_20061030_065818_2293038697161",
"/etrade/adm/etadm/web/logs/cyota/realtime/wire_20061030_065833_2293038861161",
"/etrade/adm/etadm/web/logs/cyota/realtime/wire_20061030_065914_2293038814161"
);

my ($I,$JUNK,$DATE,$TIME,$WFID,$DATESTAMP);
foreach $I (@MISSINGFILES) {
	($JUNK,$DATE,$TIME, $WFID) = split /_/, $I, 4;
	$DATESTAMP=substr($DATE,0,4) . "/" . substr($DATE,4,2) . "/" . substr($DATE,6,2);
	$DATESTAMP .= " " .substr($TIME,0,2) . ":" . substr($TIME,2,2) . ":" . substr($TIME,4,2);
	$DATESTAMP .= ":000"; #Not passed ms so just assume
	print "$DATESTAMP\n";
}



