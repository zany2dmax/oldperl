#######################################################################
# 
# deploy.pl - a program to install Patchlink Agents 
# 
# This rather comprehensive script pulls data from the SNITCH Server
# database (MySQL) and from the Patchlink Server DB (SQL Server)
# and produces a list of servers that Patchlink does not know about.
# Then, based on the OS and the SNITCH STATUS, the appropriate 
# files (Patchlink MSI, registry settings, etc.) are copied over to the
# servers and scheduled to run.
#
# Written 7/19-22/04 by Jeff Leggett
# Modified 7/29/04 by J Leggett
# - added command line options to use either SNITCH or an input text file
#
########################################################################

use Getopt::Std;
getopts('sf:o:');
	

# 
# isanip() is a subroutine we use later to make sure we have a valid IP 
# address since SNITCH is notorious for having gotten bad data in its IP 
# fields as well as a passed in text file being garbled in some way
#
sub isanip {
   if ($_[0] !~ /^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/) { return(1); }
   foreach $s (($1, $2, $3, $4)) {
       if (0 > $s || $s > 255) { return(1); }
   }
   return(0);
}
my $REMOTE_OS=$opt_o;
my $OSID=0;
open LOGFILE, "> deployment.log" or die "Unable to open LOGFILE\n";
use DBI;
#
# This section gets  the command line argument and find the appropriate 
# OS type from SNITCH.  note that SNITCH lists far more OS types than we 
# are currently supporting (in this prg) but is included in this part for 
# future use (I.e. when I get the Windows stuff working right, I will 
# expand it to rollout *IX PL Agents (hopefully)
#
my $DBH = DBI->connect('DBI:mysql:servers;snitch.interland.net:3306','username','password') or die "connecting : $DBI::errstr\n";

my $OS = $DBH->prepare("select id,os from sc_os");
    $OS->execute();
while (($ID,$DBOS)=$OS->fetchrow_array) {
    if ($DBOS eq $REMOTE_OS) { $OSID = $ID; }
}
if ($OSID == 0) {
print "No OS defined or misspelled!\n";
print "     Usage: deploy.pl -f <filename> -o <OSNAME>\n";
print "Where OSNAME is one of:\n";
print "            +----------------+\n";
print "            | os             |\n";
print "            +----------------+\n";
print "            | RedHat6        |\n";
print "            | RedHat7        |\n";
print "            | HPUX           |\n";
print "            | WindowsNT      |\n";
print "            | BSDi           |\n";
print "            | Solaris        |\n";
print "            | FreeBSD        |\n";
print "            | Windows2000    |\n";
print "            | Irix           |\n";
print "            | Cobalt         |\n";
print "            | Other          |\n";
print "            | Windows2003    |\n";
print "            | Debian         |\n";
print "            | Slackware      |\n";
print "            | Mandrake       |\n";
print "            | SuSE           |\n";
print "            | VALinux        |\n";
print "            | OpenLinux      |\n";
print "            | RedHatUnknown  |\n";
print "            | WindowsUnknown |\n";
print "            | RedHat9        |\n";
print "            +----------------+\n";
exit;
}
#
# Now we are ready to gather the SNITCH data of servers for a given OS
# 
# First we do a join across fields in SNITCH for the relevant data
#
my %SNITCHLIST = ();
my $CMD = $DBH->prepare("select ips.public,ips.private,servers.name from ips left join servers on servers.id=ips.serverid where servers.disabled != 1 and servers.deprovisioned != 1 and servers.type != \"ded\" and servers.type != \"internal\" and servers.os=$OSID");
$CMD->execute();
# 
# OK, now we have that data but it needs to be cleaned.  Our environment
# will have servers that have External (public) IP's, Internal (private)
# IP's or one or the other.  We want the Internal UNLESS that box does
# not have an internal IP.  There's logic here to grok that.
#
while (($PUBLIC,$PRIVATE,$SERVER)=$CMD->fetchrow_array) {	
    $IP = "";
    #
    # if there are no IP's defined then we write LOGDATA, and skip this record
    #
    if (($PRIVATE == NULL) && ($PUBLIC == NULL)) {
        print LOGFILE "Server $SERVER has no IP's!\n";
	next;
    }
    #
    # if there is NO Private IP, then we use the Public one
    #
    if ($PRIVATE == NULL) { $IP = $PUBLIC; } else { $IP = $PRIVATE; }
    #
    # now we make sure the Value we have in $IP is actually an IP Address
    # or we will skip this server but we WILL output the badone to the log.
    #
    if (isanip($IP) == 0) { 
        $SNITCHLIST{$IP}=$SERVER;
    } else { print LOGFILE "$SERVER had a malformed IP Address:$IP\n"; }
}
print LOGFILE "SNITCH shows ", scalar(keys(%SNITCHLIST)), " valid Servers.\n";
if ($#SNITCHLIST == 0) {
    print "I found no Servers of that OS type in SNITCH that are not \n";
    print "deprovisioned, disabled, or Self Managed\n";
    print "Exiting.....\n";
    exit;
}
#
# We now have a list of servers SNITCH knows about defined by OS Type
# Now we pull the list of servers PL has and remove them from the SNITCH 
# list to prepare for rollout.  First thing we do, is get ready to pull the 
# data from the PLUS DB by the OS type defined by the invocation of the 
# program itself.  PL uses a rather nasty OS ID string in its DB.
# Note that this is setup with an EYE towards later expanding for the *IX 
# servers
#
PARSEOS: {
    if ($OSID==4) { 
        $PLOS="00000006-0000-0000-0000-000000000003"; 
		last PARSEOS;
	}
    if ($OSID==8) { 
		$PLOS="00000006-0000-0000-0000-000000000004"; 
		last PARSEOS; 
	}
    if ($OSID==12) { 
		$PLOS="00000006-0000-0000-0000-00000000000E"; 
		last PARSEOS; 
	}
}

#
# MS SQL Server setup - We're using the Perl DBI ODBC driver for this
#
my $DSN="driver={SQL Server};Server=localhost;database=PLUS";
my $DBMH = DBI->connect("DBI:ODBC:$DSN","username",'password') or die "connecting : $DBI::errstr\n";
my $INSTALLED_AGENTS = $DBMH->prepare("select AgentName,ContactAddress from UP_Agents where OSID=\'$PLOS\'");
$INSTALLED_AGENTS->execute();
%PLAGENTS=();
while (($AGENTNAME,$CONTACT_IP)=$INSTALLED_AGENTS->fetchrow_array) {	
    # This regex strip the '\\' from the Computername
    $AGENTNAME =~ s/\\\\//g;
    $PLAGENTS{$CONTACT_IP}= lc $AGENTNAME;
}
print LOGFILE "PL DB shows ",scalar(keys(%PLAGENTS)),"Agents deployed\n";
#
# We now have two hashes of servers.  %PLAGENTS is a list of servers with
# the PL agent installed and %SNITCHLIST is a list of servers from SNITCH.
# Now we want to remove any that are in %PLAGENTS from %SNITCHLIST leaving
# a list that does not have PL installed.
# 
foreach (keys %SNITCHLIST) {
    if (exists $PLAGENTS{$_}) { delete $SNITCHLIST{$_}; } 
}

#
# Now we are going to check for network availability of these hosts with ping
#
sub pinghost {
    `ping -n 1 $_[0]` =~ /Received = 1/ ? 0 : 1;
}

print LOGFILE "We have ",scalar(keys(%SNITCHLIST)), " servers to be done\n";
if (scalar(keys(%SNITCHLIST)) > 0) {
	$FH=$opt_f;   # $REMOTE_OS . "list.txt";
	open SVRLIST, "> $FH" or die "Cannot create file $FH\n";
	while (($IP,$SERVER) = each %SNITCHLIST) { 
	    if (pinghost($IP) == 0) { print SVRLIST "$IP\n"; }
	    else { print LOGFILE "Couldn't ping $IP of $SERVER\n"; }
	}
	close SVRLIST;
	print LOGFILE "Wrote list of server IP's to be done to $FH\n";
}
 
close LOGFILE; 
