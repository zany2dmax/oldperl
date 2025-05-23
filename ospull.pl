#!perl -w

use strict;
use DBI;

#open MAILMSG , ">body.txt" or die "Can't open OUTPUT File\n";
#my %W2K3LIST = ();
#my $PLSERVER = "";
#foreach $PLSERVER("patchlink1.interland.net", "patchlink2.interland.net") {
#   my $DSN = "driver={SQL Server};Server=" . $PLSERVER . "; database=PLUS";
#   my $PLDB = DBI->connect("DBI:ODBC:$DSN","jleggett",'b@sk3tb@ll') or die "connecting : $DBI::errstr\n";
#   my $AGENTLIST = $PLDB->prepare("select Up_agents.agentname from Up_agents");
#   while ((my $AGENTNAME) = $OFFLINE_AGENTS->fetchrow_array) {
#       $AGENTNAME =~ s/^\\\\//g;
#       $W2K3LIST{$AGENTNAME} = 0;
#   }
#}

my $DBMH = DBI->connect('DBI:mysql:Interland__Servers__;hermes.corp.interland.net:3306','servers','N6ix$Vkn9') or die "connecting : $DBI::errstr\n";
my $HERMESPULL = $DBMH->prepare("SELECT
Oasis__Active__.AccountID,
Oasis__Active__.Physicalname,
Oasis__Active__.Email,
Oasis__Active__.Status,
Oasis__Active__.OS,
Oasis__Active__.WebStatus
from
Oasis__Active__,
Oasis__Active__Additional__
where
Oasis__Active__.AccountID = Oasis__Active__Additional__.AccountID
AND
(
Oasis__Active__Additional__.Description like '%Gold%'
OR
Oasis__Active__Additional__.Description like '%Platinum%'
)
AND
Oasis__Active__.OS like '%2003%'
AND
Oasis__Active__.Status = 'Active'
AND
Oasis__Active__.WebStatus = 'Active'");

$HERMESPULL->execute();
my %HERMESLIST= ();
my $CUSTCOUNT = 0;
while ((my $ACCTID,my $PNAME,my $EMAIL,my $STAT,my $OS,my $WEBSTAT)=$HERMESPULL->fetchrow_array) {
    print MAILMSG "$PNAME,$EMAIL,$OS\n";
    $HERMESLIST{$PNAME} = $EMAIL;
    $CUSTCOUNT++; 
}

print MAILMSG "There are $CUSTCOUNT entries.\n";

close MAILMSG;

system("mail.exe -s \"Windows 2003 Servers\" -f body.txt internalcontrols\@interland.com");
