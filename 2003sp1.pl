#!perl -w

use strict;
use DBI;

open PL1SVRS , "<PL12003SP1.csv" or die "Can't open PL1 Svr List\n";

my %SVRLIST = ();
while (<PL1SVRS>) {
    (my $CDRIVE, my $SERVER, my $OS) = split /,/,$_,3;
    chop $OS;
    if ($OS eq "Win2K3-") {
        $SERVER =~ s/^\\\\//g;
        $CDRIVE =~ s/.+FREE:(\d+\.\d+).+/$1/;
        $SVRLIST{$SERVER} = $CDRIVE;
    }
}
close PL1SVRS;    

open PL2SVRS , "<PL22003SP1.csv" or die "Can't open PL2 Svr List\n";
while (<PL2SVRS>) {
    (my $CDRIVE,my $SERVER,my $OS) = split /,/,$_,3;
    chop $OS;
    if ($OS eq "Win2K3-") {
        $SERVER =~ s/^\\\\//g;
        $CDRIVE =~ s/.+FREE:(\d+\.\d+).+/$1/;
        $SVRLIST{$SERVER} = $CDRIVE;
    }
}
close PL2SVRS;

my %INTERLANDSERVERS = ();
open INLDSVRS , "<InterlandServers.csv" or die "Can't open CSV file\n";
while (<INLDSVRS>) {
    (my $INLDSVR,my $JUNK) = split /,/, $_,2;
    $INLDSVR =~ s/^([^\.]+)\..*/$1/;
    $INTERLANDSERVERS{$INLDSVR} = 0;
}
foreach (keys %INTERLANDSERVERS) {
    if (exists $SVRLIST{$_}) { delete $SVRLIST{$_}; }
}

my $DBMH = DBI->connect('DBI:mysql:Interland__Servers__;hermes.corp.interland.net:3306','servers','N6ix$Vkn9') or die "connecting : $DBI::errstr\n";
open JAMESLIST , ">jameslist.csv";
foreach my $SERVER (%SVRLIST) {
   my $SVRNAME = $DBMH->quote($SERVER);
   my $HERMESPULL = $DBMH->prepare("select AccountID from Oasis__Active__ where PhysicalName = $SVRNAME");
   $HERMESPULL->execute();
   while ((my $ID)=$HERMESPULL->fetchrow_array) {
      chop($ID);
      if ($ID ne "0") { print JAMESLIST "$ID,"; }
   }
}
print JAMESLIST "\n";

close JAMESLIST;
open LOGFILE, ">scriptoutput.txt";

print LOGFILE "We have " . scalar(keys(%SVRLIST)) . " servers in Atl and Mia needing SP1\n";
print LOGFILE "The following servers do NOT have enough disk space to install SP1\n";
print LOGFILE "Remediation will be needed.  Assuming 1500Mb needed to install.\n";

my $NOTENUFF = 0;
foreach (keys %SVRLIST) {
    if ($SVRLIST{$_} <= 1500.0) {
	print LOGFILE "$_ only has $SVRLIST{$_} MB of space on its C:\ drive\n";
	$NOTENUFF++;
    }
}

print LOGFILE "We have $NOTENUFF servers in Atl and Mia without enough space to install.\n";
close LOGFILE;
