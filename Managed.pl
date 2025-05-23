#!perl -w

use strict;
use DBI;

open LOGFILE, ">MANAGED.csv" or die "Can't open output\n";

my $DSN="driver={SQL Server};Server=192.168.14.87; database=RPTData";
my $DBMH = DBI->connect("DBI:ODBC:$DSN","OpsLink",'AL3N6PASSET946FL') or die "connecting : $DBI::errstr\n";
my $MANAGEDPULL = $DBMH->prepare("Exec usp_rpt_Managed_Services_Customers '10/01/2004'");
$MANAGEDPULL->execute();
while ((my $ACCOUNTID, my $DOMAIN, my $STARTDATE, my $SALESREP, 
 	my $ACCOUNTSTATUS, my $MRC, my $HOSTINGPLAN,my $HOSTINGFAMILY, 
	my $DESCRIPTION, my $CANCELDATE, my $TICKETS, my $OPENTICKETS, 
	my $PROVLOCATION, my $SERVERNAME, my $IPADDR)=$MANAGEDPULL->fetchrow_array) {
   # Scrub the data a bit, some lines return without a SERVERNAME, 
   # which is worthless to us for this program
   if ($SERVERNAME ne "") { 
      print LOGFILE "$PROVLOCATION,$SERVERNAME,$IPADDR\n";
   }
}
close LOGFILE;
