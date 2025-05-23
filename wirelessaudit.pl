#!/usr/bin/perl -w
#
# wirelessaudit.pl - script to produce report of all found Wireless AP's
#		     and compare them to known MAC addresses onm our network
#
# Written July 21-22, 2005 by Jeff Leggett, Security Engineering
use strict;
use Getopt::Std;
use LWP::Simple;
use vars qw($opt_i $opt_o);
getopts('i:o:');

my $usage = <<ENDUSAGE;
usage: wirelessaudit.pl -i <INPUTFILE> -o <OUTPUTFLE>
where: INPUTFILE is the saved Wireless Scanner Output file
       OUTPUTFILE is the report you wish to produce
ENDUSAGE

if ((!$opt_i) || (!$opt_o)) { print STDERR $usage; exit 1; } 
open AUDITFILE, "< $opt_i" or die "Can't open $opt_i\n";
open REPORTFILE, "> $opt_o" or die "Can't open $opt_o\n";
my $RECORD = 0;
my $J = 0;
my $CHANNEL = "";
my $ESSID = "";
my $MAC = "";
$JUNK = "";
my @MACLIST;
print REPORTFILE "Channel\t\tMAC Addr\t\t Name\n";
while (<AUDITFILE>) {
    chomp;
    if ($_ =~ /Channel/) { 
	($JUNK, $CHANNEL) = split /:/,$_,2; 
    	print REPORTFILE "$CHANNEL\t\t";
 	next; 
    }
    if ($_ =~ /bssmac/) { 
	($JUNK, $MAC) = split /:/,$_,2; 
	$MAC = substr ($MAC, 1);
	@MACLIST = hexmath($MAC);
	for ($J = 0; $J <= 8; $J++) {
	    my $CONTENT = get("http://newnoc/inventory/ShowSearchResults.php?show-inventory-physicalname=1&show-inventory_mac_casenumber-privateip=1&show-inventory_mac_casenumber-pubip=1&or_free_pubmac_privatemac=$MACLIST[$J]");
#	    if ($CONTENT =~ /0 rows returned/ ) {
		
	    print $CONTENT;
        }
	print REPORTFILE "$MAC\t\t";
 	next; 
    }
    if ($_ =~ /essid:/) { 
	($JUNK, $ESSID) = split /:/,$_,2; 
	$RECORD++; 
	print REPORTFILE "$ESSID\n";
 	next; 
    }
}
print REPORTFILE "Processed $RECORD Access Points\n";
close (AUDITFILE);
close (REPORTFILE);

sub hexmath {
   my $HEXNUM = @_[0];
   my $ENDMAC = substr ($HEXNUM,-4);
   my $FRONTMAC = substr ($HEXNUM,0,8);
   $NUMBER = hex($ENDMAC);
   my @MACLIST;
   my $TMPN = 0;
   for (my $I = -4; $I <= 4; $I++) {
       $TMPN = $NUMBER + $I;
       $MACLIST[$I+4] = $FRONTMAC . (sprintf "%lx", $TMPN);
   }
   return @MACLIST;
}
   
