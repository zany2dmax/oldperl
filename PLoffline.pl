#!perl -w
############################################################################
#
# PLoffline.pl 
# Written 11/17/04-11/18/04 by Jeff Leggett
#
# This program reads the PLUS DB for agents in offline mode
# Then calculates the # of days a given agent has been offline, then 
# based on number of days offline, we set them to disabled.
# THis Currently we set them disabled after 15 days but that is defined 
# by the $MAXOFFLINEDAYS variable, so change to suit.
#
# Modified 1/17/05-1/18/05 by Jeff Leggett
# * Added Mail::sendmail code to email Sec Eng 
# * compared to SNITCH's list of bad (deprov/disabled) servers
# 
use strict;
use DBI;
use Date::Calc qw(Delta_Days);
use Mail::Sendmail qw(sendmail %mailcfg);

my $MAXOFFLINEDAYS = 30;

my @MSGHEADER = undef;
open LOGFILE , ">PLoffline.log" or die "Unable to open LOGFILE\n";

#
# Setup the PLS DB calls for use
#
my $DSN="driver={SQL Server};Server=localhost; database=PLUS";
my $DBMH = DBI->connect("DBI:ODBC:$DSN","jleggett",'b@sk3tb@ll') or die "connecting : $DBI::errstr\n";

my $OFFLINE_AGENTS= $DBMH->prepare("select Up_agents.Agentname, Up_Agents.LastContactDate, Up_Agents.ContactAddress, DateDiff (day, Up_Agents.LastContactDate, getdate()) as DaysOffline from Up_Agents left outer join vAgents_Status On Vagents_Status.Status=-2 and Vagents_Status.AgentID= Up_Agents.AgentID WHERE (Vagents_Status.Status IS NOT NULL) order by DaysOffline");
$OFFLINE_AGENTS->execute();
# 
# Now take the output from above and put in a HASH, to use later.
# We clean the AGENTNAME and build the HASH of servers based on the 
# MAXOFFLINE days declared above.
# 
my %OFFLINESERVERS = ();
while ((my $AGENTNAME, my $LASTDATE, my $CONTACT_IP, my $DAYSOFFLINE)=$OFFLINE_AGENTS->fetchrow_array) {
    $AGENTNAME =~ s/^\\\\//g;
    if ($DAYSOFFLINE >= $MAXOFFLINEDAYS) {  
       #
       # Build a HASH of servers of $MAXOFFLINEDAYS
       #
       $OFFLINESERVERS{$AGENTNAME} = $DAYSOFFLINE;
       push (@MSGHEADER, "Server: $AGENTNAME, IP: $CONTACT_IP, Last Contacted: $LASTDATE, Days Offline: $DAYSOFFLINE\n");
       print LOGFILE "Server: $AGENTNAME, IP: $CONTACT_IP, Last Contacted: $LASTDATE, Days Offline: $DAYSOFFLINE\n";
    }
}
#
# OK, we have a HASH of offline servers, let's see which ones are dead to SNITCH
#
my $DBH = DBI->connect('DBI:mysql:servers;snitch.interland.net:3306','jleggett','jeff can read') or die "connecting : $DBI::errstr\n";
my $SNITCH_SHOWS_DEAD = 0;
foreach my $SERVER (%OFFLINESERVERS) {
   my $AGENTNAME = $DBH->quote($SERVER);
   my $SNITCHPULL = $DBH->prepare("select name from servers where name = $AGENTNAME and (disabled = 1 or deprovisioned = 1)");
   $SNITCHPULL->execute();
   while ($SERVER=$SNITCHPULL->fetchrow_array) {
      push (@MSGHEADER, "$SERVER shows deprovisioned or disabled in SNITCH\n");
      print LOGFILE "$SERVER shows deprovisioned or disabled in SNITCH\n";
      $SNITCH_SHOWS_DEAD++;
   }
}
my $TMPSTRING= "Number of Agents showing Offline for more than $MAXOFFLINEDAYS days: " . scalar(keys(%OFFLINESERVERS)) . "\n";
push (@MSGHEADER, $TMPSTRING);
print LOGFILE $TMPSTRING;
push (@MSGHEADER, "Number of offline agents showing deprovisioned or disabled in SNITCH: $SNITCH_SHOWS_DEAD\n");
print LOGFILE "Number of offline agents showing deprovisioned or disabled in SNITCH: $SNITCH_SHOWS_DEAD\n";

my %mail = ();

$mail{To}= 'securityeng@interland.com';
# $mail{To}= 'jleggett@interland.com';
$mail{From}= 'patchlink1@patchlink1.interland.net';
$mail{Subject} = 'Patchlink Offline Report';
$mail{Message} = "@MSGHEADER";
$mailcfg{smtp} = [qw(mailhub.registeredsite.com)];

sendmail (%mail) or die $Mail::Sendmail::error;
print LOGFILE "$Mail::Sendmail::Log";

close LOGFILE;

