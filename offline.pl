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
# * Modified 9/15/05 by Jeff Leggett
#   Added sub cleanup() and code to exit if no offline servers
#   Sorts the output servers alphabetically for easier matching to PL.
#
#############################################################################
use strict;
use DBI;
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

sub cleanup { 
my $LOCATION = $_[0]; 
close RAWDATA;
close LOGFILE;
system ("d:\\scripts\\mail.exe -s \"$LOCATION Patchlink Offline Report\" -f d:\\scripts\\BodyMsg.txt securityeng\@peer1.com");
}

my $PLSERVER;
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

# Adjust this at will... One month seemed like a good number, but customers 
# 'COULD' take longer than this to pay up an account.
#
my $MAXOFFLINEDAYS = 7;

open LOGFILE , ">BodyMsg.txt" or die "Unable to open LOGFILE\n";
open RAWDATA , ">PLOffline.csv" or die "Unable to open RAWDATA file\n";

print LOGFILE "Patchlink offline Report for ";
print LOGFILE localtime() . "\n";
print LOGFILE "\nThe report is generated from the Security Engineering Reporting Server\n";
print LOGFILE "Using information from the Patchlink Servers and the Hermes OASIS Data Repository\n";
print LOGFILE "Contact Security Engineering for Questions\n\n\n";
print LOGFILE "---------------------------------------------------------------------------\n";

#
# Setup the PLUS DB calls for use for the Patchlink Server specified 
#
my $DSN="driver={SQL Server};Server=" . $PLSERVER . "; database=PLUS";
my $DBMH = DBI->connect("DBI:ODBC:$DSN","jleggett",'b@sk3tb@ll') or die "connecting : $DBI::errstr\n";

my $OFFLINE_AGENTS= $DBMH->prepare("select Up_agents.Agentname, Up_Agents.LastContactDate, Up_Agents.ContactAddress, DateDiff (day, Up_Agents.LastContactDate, getdate()) as DaysOffline from Up_Agents left outer join vAgents_Status On Vagents_Status.Status=-2 and Vagents_Status.AgentID= Up_Agents.AgentID WHERE (Vagents_Status.Status IS NOT NULL) order by DaysOffline");
$OFFLINE_AGENTS->execute();
# 
# Now take the output from above and put in a HASH, to use later.
# We clean the AGENTNAME and build the HASH of servers based on the 
# MAXOFFLINE days declared above.  
# 
my %OFFLINESERVERS = ();
while ((my $AGENTNAME, my $LASTDATE, my $CONTACT_IP, my $DAYSOFFLINE)= $OFFLINE_AGENTS->fetchrow_array) {
    $AGENTNAME =~ s/^\\\\//g;
    if ($DAYSOFFLINE >= $MAXOFFLINEDAYS) {  
       #
       # Build a HASH of servers of $MAXOFFLINEDAYS
       #
       $OFFLINESERVERS{$AGENTNAME} = $DAYSOFFLINE;
       print RAWDATA "$AGENTNAME, $CONTACT_IP, $LASTDATE, $DAYSOFFLINE\n";
    }
}
#
# if we have no offline servers, nothing to be done, exit
#
if (scalar(keys(%OFFLINESERVERS)) == 0) { 
   print LOGFILE "No offline servers in $opt{l}\n";	
   cleanup($opt{l});
   exit; 
}
#
# otherwise, let's get started
#
print LOGFILE "We have " . scalar(keys(%OFFLINESERVERS)) . " Servers Offline in Patchlink.\n\n";
#
# OK, we have a HASH of offline servers, let's see which ones are dead to OASIS
#
$DBMH = DBI->connect('DBI:mysql:Interland__Servers__;hermes.corp.interland.net:3306','servers','N6ix$Vkn9') or die "connecting : $DBI::errstr\n";
my $OASIS_SHOWS_DEAD = 0;
my %DEADINOASIS = ();
my %ACTIVEINOASIS = ();
#
# First, let's get any that have been Cancelled in OASIS
#
foreach my $SERVER (%OFFLINESERVERS) {
   my $AGENTNAME = $DBMH->quote($SERVER);
   my $OASISPULL = $DBMH->prepare("select PhysicalName from Oasis__Cancelled__ where Oasis__Cancelled__.PhysicalName = $AGENTNAME");
   $OASISPULL->execute();
      while ((my $PN)=$OASISPULL->fetchrow_array) {
      print RAWDATA "Oasis (Cancelled) Returned:,$PN\n";
      if ($PN ne "") {
         $OASIS_SHOWS_DEAD++;
         $DEADINOASIS{$SERVER} = $OFFLINESERVERS{$SERVER};
      }
   }
}
# print LOGFILE "The following servers have been deprovisioned and can be deleted from Patchlink\n";
# print LOGFILE "Server\n";
##  print LOGFILE "----------------\n";
foreach (keys %DEADINOASIS) {
#    print LOGFILE "$_\n";
   delete $OFFLINESERVERS{$_} if exists $OFFLINESERVERS{$_};
}
print RAWDATA "We have " . scalar(keys(%OFFLINESERVERS)) . " Servers to work on after checking cancelled table.\n";
print RAWDATA "Oasis shows " . scalar(keys(%DEADINOASIS)) . " after checking Cancelled table\n";
foreach my $SERVER (%OFFLINESERVERS) {
   my $AGENTNAME = $DBMH->quote($SERVER);
   my $OASISPULL = $DBMH->prepare("select PhysicalName,PrimaryIP,Status,Webstatus name from Oasis__Active__ where Oasis__Active__.PhysicalName = $AGENTNAME");
   $OASISPULL->execute();
   while ((my $PN, my $IP, my $STAT, my $WEB)=$OASISPULL->fetchrow_array) {
      print RAWDATA "OASIS Returned:,$PN,$IP,$STAT,$WEB\n";
# Note to add code here for checking for return data viability

#
# This next section deals with Servers in OASIS that are STATUS active
#
      if ($STAT eq "Active") { 
	  if ($WEB eq "Active") {
#	     print LOGFILE "$PN\t\t$IP\t\t$OFFLINESERVERS{$SERVER}\n"; 
	     $ACTIVEINOASIS{$SERVER} = $OFFLINESERVERS{$SERVER};
	  }
	  if (($WEB eq "Deprovisioned") || 
              ($WEB eq "Frozen") || 
	      ($WEB eq "Unknown")) {
             $OASIS_SHOWS_DEAD++;
	     $DEADINOASIS{$SERVER} = $IP;
          }   
      }
      if (($STAT eq "Do Not Renew") || 
        ($STAT eq "Collection") ||
        ($STAT eq "Manual Collection") ||
        ($STAT eq "Past Due")) {
         if ($WEB ne "Active") {
            $OASIS_SHOWS_DEAD++;
	    $DEADINOASIS{$SERVER} = $IP;
	 }
      }
   }
}
foreach (keys %ACTIVEINOASIS) {
   delete $OFFLINESERVERS{$_} if exists $OFFLINESERVERS{$_};
}
print RAWDATA "Oasis shows DEAD at " . scalar(keys(%DEADINOASIS)) . " after checking Active table\n";

print LOGFILE "\n\nThe following servers are not active in OASIS. This may be from NEVER having been input\nto OASIS, or having gone offline, or been deprovisioned, etc.  Once determination\nis made the server no longer exists the Agent can be disabled to free \nup a Patchlink license.\n\n";
print LOGFILE "Server\t\t\tDays Offline\n";
print LOGFILE "------\t\t\t----------\n";
while ((my $PN, my $DAYS) = each(%DEADINOASIS)) {
   if ((length $PN) < 7) {
      print LOGFILE "$PN\t\t\t$DAYS\n"; 
   } else { print LOGFILE "$PN\t\t$DAYS\n"; }
   delete $OFFLINESERVERS{$PN};
}

print LOGFILE "\n\nThe following " . scalar(keys(%ACTIVEINOASIS)) . " servers are active in OASIS and *SHOULD* be online.  Remediation is needed. \n\n";
print LOGFILE "Server\n";
print LOGFILE "-------------\n";
foreach (sort keys %ACTIVEINOASIS) {
   print LOGFILE "$_\n"; 
}

print LOGFILE "\n\nThe remaining " . scalar(keys(%OFFLINESERVERS)) . " servers are not in OASIS in any form.  A determination of their status and remediation may be needed. \n\n";
print LOGFILE "Server\n";
print LOGFILE "-------------\n";
foreach (sort keys %OFFLINESERVERS) {
   print LOGFILE "$_\n"; 
}

cleanup($opt{l});

