#!perl -w

use strict;
use DBI;

my $SHAREDCNT = 0;
my $PLSERVER = "patchlink2.interland.net";

my $DSN="driver={SQL Server};Server=" . $PLSERVER . "; database=PLUS";
my $DBMH = DBI->connect("DBI:ODBC:$DSN","jleggett",'b@sk3tb@ll') or die "connecting : $DBI::errstr\n";
my $AGENTS= $DBMH->prepare("select Up_agents.Agentname, Up_Agents.ContactAddress from Up_Agents left outer join vAgents_Status On Vagents_Status.Status=-2 and Vagents_Status.AgentID= Up_Agents.AgentID");

$AGENTS->execute();
my $DBM = DBI->connect('DBI:mysql:Interland__Servers__;hermes.corp.interland.net:3306','servers','N6ix$Vkn9') or die "connecting : $DBI::errstr\n";
my $SVRNAME = "";
my %SERVERS = ();
while ((my $AGENTNAME, my $CONTACT_IP)= $AGENTS->fetchrow_array) {
    $AGENTNAME =~ s/^\\\\//g;
    $SERVERS{$AGENTNAME} = $CONTACT_IP;
    $SVRNAME = $DBM->quote($AGENTNAME);
    my $HERMES = $DBM->prepare("select Oasis__Active__.PhysicalName, Oasis__Active__.AccountID from Oasis__Active__, Oasis__Active__Additional__ WHERE (Oasis__Active__.AccountID = Oasis__Active__Additional__.AccountID) AND (Oasis__Active__Additional__.Description like '%shared%') AND (Oasis__Active__.Physicalname = $SVRNAME)");
    $HERMES->execute();
    while ((my $SHAREDSVR, my $ACCTID)=$HERMES->fetchrow_array) {
       print "$SHAREDSVR,$ACCTID,$SERVERS{$SHAREDSVR}\n";
       $SHAREDCNT++;
    }
}

print "There are " . scalar(keys(%SERVERS)) . " servers in $PLSERVER\n";


print "There are $SHAREDCNT Shared servers in Patchlink\n";
