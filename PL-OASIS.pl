#!perl -w
############################################################################
#
# PLoffline.pl 
# Written 11/17/04-11/18/04 by Jeff Leggett
#
# This program reads the PLUS DB for agents in offline mode
# Then calculates the # of days a given agent has been offline, then 
# based on number of days offline, we set them to disabled.
# THis Currently we set them disabled after 7 days but that is defined 
# by the $MAXOFFLINEDAYS variable, so change to suit.
#
# Modified 1/17/05-1/18/05 by Jeff Leggett
# * Added Mail::sendmail code to email Sec Eng 
# * compared to SNITCH's list of bad (deprov/disabled) servers
# * Moved the Date computations to the SQL Server instead if in perl
# 
# Modified 2/2/05 by Jeff Leggett
# * Pulled SNITCH equiv from OASIS data Mart
#
# Modified 2/8/05 by Jeff Leggett
# * Pulled from MIA PL server as well
# * Commented out the SNITCH stuff - am told I should consider OASIS
#   authoritative
#
# Modified 5/16/05 by Jeff Leggett
# * Added the Pull from the Managed Services Stored proc from OASIS
# * Reformatting of the Data Output format
#
# Modified 5/23/05 by Jeff Leggett
# * Refactored the OASIS data to use the Data Store setup in MIA from the
#   hourly OASIS pull of active servers.  OASIS uses a lot of XML, and 
#   requires a 4 part JOIN just to determine of a given server is active.
#   This has a table of Active Servers by Server Physical name which matches
#   the names in Patchlink server.
#
# Modified 8/10/05-9/02/05 by Jeff Leggett
# * Refactoring again to use hermes...  MOF, moving to a new file so 
#   see OFFLINE.pl
use strict;
use DBI;

my $MAXOFFLINEDAYS = 7;

open LOGFILE , ">PLoffline.csv" or die "Unable to open LOGFILE\n";
print LOGFILE "Server,IP,Last Contacted,Days Offline\n";
#
# Setup the PLUS DB calls for use for the ATLANTA server
#
my $DSN="driver={SQL Server};Server=patchlink1.interland.net; database=PLUS";
my $DBMH = DBI->connect("DBI:ODBC:$DSN","jleggett",'b@sk3tb@ll') or die "connecting : $DBI::errstr\n";

my $OFFLINE_AGENTS= $DBMH->prepare("select Up_agents.Agentname, Up_Agents.LastContactDate, Up_Agents.ContactAddress, DateDiff (day, Up_Agents.LastContactDate, getdate()) as DaysOffline from Up_Agents left outer join vAgents_Status On Vagents_Status.Status=-2 and Vagents_Status.AgentID= Up_Agents.AgentID WHERE (Vagents_Status.Status IS NOT NULL) order by DaysOffline");
$OFFLINE_AGENTS->execute();
# 
# Now take the output from above and put in a HASH, to use later.
# We clean the AGENTNAME and build the HASH of servers based on the 
# MAXOFFLINE days declared above.  Have to do this first for 
# ATLANTA then for MIAMI
# 
my %OFFLINESERVERS = ();
while ((my $AGENTNAME, my $LASTDATE, my $CONTACT_IP, my $DAYSOFFLINE)= $OFFLINE_AGENTS->fetchrow_array) {
    $AGENTNAME =~ s/^\\\\//g;
    if ($DAYSOFFLINE >= $MAXOFFLINEDAYS) {  
       #
       # Build a HASH of servers of $MAXOFFLINEDAYS
       #
       $OFFLINESERVERS{$AGENTNAME} = $DAYSOFFLINE;
#       print LOGFILE "$AGENTNAME, $CONTACT_IP, $LASTDATE, $DAYSOFFLINE\n";
    }
}

#
# Setup the PLUS DB calls for use for the MIAMI server
# 
my $DSNM="driver={SQL Server};Server=patchlink2.interland.net; database=PLUS";
my $DBMHM = DBI->connect("DBI:ODBC:$DSNM","jleggett",'b@sk3tb@ll') or die "connecting : $DBI::errstr\n";

my $MIA_OFFLINE_AGENTS= $DBMHM->prepare("select Up_agents.Agentname, Up_Agents.LastContactDate, Up_Agents.ContactAddress, DateDiff (day, Up_Agents.LastContactDate, getdate()) as DaysOffline from Up_Agents left outer join vAgents_Status On Vagents_Status.Status=-2 and Vagents_Status.AgentID= Up_Agents.AgentID WHERE (Vagents_Status.Status IS NOT NULL) order by DaysOffline");
$MIA_OFFLINE_AGENTS->execute();

while ((my $AGENTNAME, my $LASTDATE, my $CONTACT_IP, my $DAYSOFFLINE)= $MIA_OFFLINE_AGENTS->fetchrow_array) {
    $AGENTNAME =~ s/^\\\\//g;
    if ($DAYSOFFLINE >= $MAXOFFLINEDAYS) {  
       #
       # Continue building the HASH of servers of $MAXOFFLINEDAYS from MIA
       #
       $OFFLINESERVERS{$AGENTNAME} = $DAYSOFFLINE;
#       print LOGFILE "$AGENTNAME, $CONTACT_IP, $LASTDATE, $DAYSOFFLINE\n";
    }
}
#
# There is a stored procedure in the OASIS Data Mart for the Managed Services
# plans, that gives us good information and *SHOULD* only return ACTIVE 
# servers within OASIS on that plan.  We'll use that here to make better use 
# of the OFFLINE agents info from above.
#
my %MANAGEDSERVERS = ();
$DSN="driver={SQL Server};Server=192.168.14.87; database=RPTData";
$DBMH = DBI->connect("DBI:ODBC:$DSN","OpsLink",'AL3N6PASSET946FL') or die "co
nnecting : $DBI::errstr\n";
my $MANAGEDPULL = $DBMH->prepare("Exec usp_rpt_Managed_Services_Customers '10/01/2004'");
$MANAGEDPULL->execute();
while ((my $ACCOUNTID, my $DOMAIN, my $STARTDATE, my $SALESREP,
        my $ACCOUNTSTATUS, my $MRC, my $HOSTINGPLAN,my $HOSTINGFAMILY,
        my $DESCRIPTION, my $CANCELDATE, my $TICKETS, my $OPENTICKETS,
        my $PROVLOCATION, my $SERVERNAME, my $IPADDR)=$MANAGEDPULL->fetchrow_array) { 
   # Scrub the data a bit, some lines return without a SERVERNAME,
   # which is worthless to us for this program
   if ($SERVERNAME ne "") {
      $MANAGEDSERVERS{$SERVERNAME} = 0;
      #print LOGFILE "$PROVLOCATION,$SERVERNAME,$IPADDR\n";
   }
}

# Compare the HASH of OFFLINE servers to the HASH of MANAGED.  If we find 
# a match then we have a problem, sicne that server *SHOULD* be up.
my @PROBLEMSERVERS = ();
foreach (keys %OFFLINESERVERS) {
   if exists ($MANAGEDSERVERS{$_}) {
      push (@PROBLEMSERVERS, $_); 
      # And delete these from the hash off offline servers, since we know 
      # they have a problem, but are now in new HASH, we can speed up process 
      # for next section
      delete ($OFFLINESERVERS{"$_"});
   }
}
my $PROBLEMSVRCOUNT = 0;
foreach my $SERVER (@PROBLEMSERVERS) {
   print LOGFILE "$SERVER should be up but is OFFLINE! - needs manual checking\n";
   $PROBLEMSVRCOUNT++;
}   

#
# OK, we have a HASH of offline servers, let's see which ones are dead to OASIS
#
$DBMH = DBI->connect('DBI:mysql:servers;hermes.corp.interland.net','N6ix$bkn9') or die "connecting : $DBI::errstr\n";
my $OASIS_SHOWS_DEAD = 0;
foreach my $SERVER (%OFFLINESERVERS) {
   my $AGENTNAME = $DBMH->quote($SERVER);
   my $OASISPULL = $DBMH->prepare("select dbo.Server.ServerName name from dbo.Server where dbo.Server.ServerName = $AGENTNAME and dbo.Server.Live = 'No'");
   $OASISPULL->execute();
   while ($SERVER=$OASISPULL->fetchrow_array) {
      print LOGFILE "$SERVER shows dead in OASIS\n";
      $OASIS_SHOWS_DEAD++;
   }
}

my $TMPSTRING= "Number of Agents showing Offline for more than $MAXOFFLINEDAYS days: " . scalar(keys(%OFFLINESERVERS)) . "\n";
print LOGFILE $TMPSTRING;
print LOGFILE "Number of servers needing some manual checking: $PROBLEMSVRCOUNT\n";
print LOGFILE "Number of offline agents dead in OASIS: $OASIS_SHOWS_DEAD\n";

close LOGFILE;

system ("mail.exe -a PLoffline.csv -s \"Patchlink Offline Report\" -f BodyMsg.txt jleggett\@interland.com");

