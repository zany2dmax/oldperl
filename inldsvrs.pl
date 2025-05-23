#!perl -w

use strict;
use DBI;

my $DAYSOFFLINE = 0;

my $DSN="driver={SQL Server};Server=patchlink1.interland.net; database=PLUS";
my $DBMH = DBI->connect("DBI:ODBC:$DSN","jleggett",'b@sk3tb@ll') or die "connecting : $DBI::errstr\n";

my $OFFLINE_AGENTS= $DBMH->prepare("select Up_agents.Agentname from Up_Agents");
$OFFLINE_AGENTS->execute();
my %PLSERVERS = ();
while ((my $AGENTNAME)= $OFFLINE_AGENTS->fetchrow_array) {
    $AGENTNAME =~ s/^\\\\//g;
    $PLSERVERS{$AGENTNAME} = $DAYSOFFLINE;
}
my $ATLCOUNT = scalar(keys(%PLSERVERS));

my $DSNM="driver={SQL Server};Server=patchlink2.interland.net; database=PLUS";
my $DBMHM = DBI->connect("DBI:ODBC:$DSNM","jleggett",'b@sk3tb@ll') or die "connecting : $DBI::errstr\n";

my $MIA_OFFLINE_AGENTS= $DBMHM->prepare("select Up_agents.Agentname from Up_Agents");
$MIA_OFFLINE_AGENTS->execute();

while ((my $AGENTNAME)= $MIA_OFFLINE_AGENTS->fetchrow_array) {
    $AGENTNAME =~ s/^\\\\//g;
    $PLSERVERS{$AGENTNAME} = $DAYSOFFLINE;
}

my $MIACOUNT = (scalar(keys(%PLSERVERS)) - $ATLCOUNT);

my %INTERLANDSERVERS = ();
open INLDSVRS , "<InterlandServers.csv" or die "Can't open CSV file\n";
while (<INLDSVRS>) {
    (my $INLDSVR,my $JUNK) = split /,/, $_,2;
    $INLDSVR =~ s/^([^\.]+)\..*/\1/;
    $INTERLANDSERVERS{$INLDSVR} = $DAYSOFFLINE;
}
close INLDSVRS;
open LOGFILE , ">svroutput.txt";
print LOGFILE "We have $ATLCOUNT Atlanta Servers\n";
print LOGFILE "We have $MIACOUNT Miami Servers\n";

print LOGFILE "We have " . scalar(keys(%PLSERVERS)) . " Servers in Patchlink before comparisons\n";
print LOGFILE "We have " . scalar(keys(%INTERLANDSERVERS)) . " Servers in Spreadsheet (Interland Servers.csv)\n";

my @INLDSVRSINPL = ();
foreach (keys %PLSERVERS) { push (@INLDSVRSINPL, $_) if exists $INTERLANDSERVERS{$_}; }
my $SVR = "";
my $MIAINLD = 0;
my $ATLINLD = 0;

print LOGFILE "\nInterland Servers in Patchlink:\n";
foreach $SVR (@INLDSVRSINPL) { 
    if ($SVR =~ m/MIA$/) { $MIAINLD++; }
    if ($SVR =~ m/ATL2$/) { $ATLINLD++; }
    delete $PLSERVERS{$SVR};
}
print LOGFILE "We have " . scalar(@INLDSVRSINPL) . " Servers in Patchlink belonging to Interland.\n";
print LOGFILE "Of these $ATLINLD are in Atlanta and $MIAINLD are in Miami\n";
print LOGFILE "\nWe have " . scalar(keys(%PLSERVERS)) . " Servers in Patchlink belonging to Peer1\n";

my $DBH = DBI->connect('DBI:mysql:Interland__Servers__;hermes.corp.interland.net:3306','servers','N6ix$Vkn9') or die "connecting : $DBI::errstr\n";
my $HERMES = $DBH->prepare("SELECT Oasis__Active__.AccountID, Oasis__Active__.Physicalname, Oasis__Active__.Status, Oasis__Active__.OS, Oasis__Active__.WebStatus from Oasis__Active__, Oasis__Active__Additional__ where Oasis__Active__.AccountID = Oasis__Active__Additional__.AccountID AND ( Oasis__Active__Additional__.Description like '%Gold%' OR Oasis__Active__Additional__.Description like '%Platinum%' ) AND Oasis__Active__.Status = 'Active' AND Oasis__Active__.WebStatus = 'Active' ");

(my $ACCTID, my $PHYSNAME, my $STATUS, my $OS, my $WEBSTAT) = "";
my %HERMESHASH = ();
$HERMES->execute();
while ((my $ACCTID, my $PHYSNAME, my $STATUS, my $OS, my $WEBSTAT) = $HERMES->fetchrow_array) {
    $HERMESHASH{$PHYSNAME} = $OS;
}    
print LOGFILE "We have " . scalar(keys(%HERMESHASH)) . " Managed Servers in HERMES\n";
my @PLINHERMES = ();
print LOGFILE "The following servers are in Hermes but not in Patchlink\n";
foreach (keys %HERMESHASH) {
    if (exists $PLSERVERS{$_}) { push (@PLINHERMES, $_); }
    else { print LOGFILE "$_\n"; }
}
print LOGFILE "\nWe have " . scalar(@PLINHERMES) . " Patchlink Servers in Hermes\n";
close LOGFILE;
    
