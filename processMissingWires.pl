#!/etrade/pkgs/linux/intel/perl/5.8.0/bin/perl -w
#
# processMissingWires.pl - a program to compare the hourly batch runs of 
# Wire data to the Real Time feed and determine if any wires were missed, 
# and to package up and send to Cyota when any are found.
#
# 10/30/2006 - Jeff Leggett - initial coding begun

use strict;
use Env;
Env::import();
use Getopt::Long;
use Time::Local;
use Getopt::Std;
use et_log;
use Date::Calc qw(Add_Delta_DHMS);
Et_Log_Init();

sub Usage {
    print "Usage: processMissingWires.pl [-h] [-d YYYYMMDDHH]\n";
    print "  -h : This help output\n";
    print "  -d : An optional datestamp in the form of YYYYMMDDHH\n\n";
    exit 1;
}

sub trimspaces {
    my @OUT = @_;
    for (@OUT) {
	s/^\s+//;
	s/\s+$//;
    }
    return wantarray ? @OUT : $OUT[0];
}

my %OPTS;
getopts('hd:', \%OPTS);

if ($OPTS{h}) { Usage; } 
#
# Setup directories to use and times to process (formatted for later regex)
#
my ($YEAR, $MONTH, $DAY, $HOUR, $MIN, $SEC);
my $RTLOGSDIR=$ENV{"ET_INSTANCE_ROOT"} . "/cyota/realtime";
my $BATCHDIR=$ENV{"ET_INSTANCE_ROOT"} . "/logs/cyota/wire/frequent";
#
# if we specify a YYYYMMDDHH onthe cmdline, we use that for the TP's
# Otherwise, we set our TP to start from 2 hours ago to 1 hour ago
# This is on the assumption that if you are running it from cron you want
# to go back a bit to not miss any of the updates coming in from other programs
# but older than that is assured of being there from both batch and real time
#
if ($OPTS{d}) {
    $YEAR = substr $OPTS{d},0,4;
    $MONTH = substr $OPTS{d},4,2;
    $DAY = substr $OPTS{d},6,2;
    $HOUR = substr $OPTS{d},-2,2;
}
else {
    my $CURYEAR=(localtime)[5]+1900;
    my $CURMONTH=(localtime)[4]+1;
    my $CURDAY=(localtime)[3];
    my $CURHOUR=(localtime)[2];
    my $END_HOUR=(localtime)[2]-1;
    #
    # Using Add_Delta_DHMS function lets us not worry about previous hours over
    # a midnight/day change
    #
    ($YEAR, $MONTH, $DAY, $HOUR, $MIN, $SEC) = Add_Delta_DHMS(
        $CURYEAR, $CURMONTH, $CURDAY, $END_HOUR, 0, 0, 0, -1, 0, 0);
    if (length($HOUR) == 1) { $HOUR = "0" . $HOUR; } 
}
#
# Now we can build the filenames we need to work with
#
my $BATCHFILE="wire_" . $YEAR . $MONTH . $DAY . "_" . $HOUR . "00.txt";
my $BATCHPATH=$BATCHDIR . "/" . $BATCHFILE;
my $RTFILES="wire_" . $YEAR . $MONTH . $DAY . "_" . $HOUR . "*";
my $RTPATH = $RTLOGSDIR . "/" . $RTFILES;
#
# Find how many Batch entries we have 
# 
my $BATCHCOUNT = `wc -l < $BATCHPATH`;
$BATCHCOUNT = trimspaces($BATCHCOUNT);
Et_Run_Log("We have $BATCHCOUNT batch entries in this hour in $BATCHPATH");
#
# Find out how many Real Time Entries we have
# 
my $RTCOUNT = `ls $RTPATH | wc -l`;
$RTCOUNT = trimspaces($RTCOUNT);
Et_Run_Log("We have $RTCOUNT real time entries in this hour in $RTPATH");
#
# We want to find the list of fileS (plural) in the real time feed that are 
# missing the corresponding WF_ID value in the list of a given hours LINES in
# the equivalent batch FILE (singular).  note the 1 to X relationship of files 
# batch versus real time.  (IOW, for any given hour of data we always have 
# precisely 1 BATCH file to anywhere from 1 to N files from the real time feed.
# So, this code does that.  
# 
if ($RTCOUNT > $BATCHCOUNT) {
    my @BATCHLIST;
    open BATCHINPUT, "< $BATCHPATH";
    while (<BATCHINPUT>) {
        push (@BATCHLIST, $_);
    }
    my @RTFILELIST = `ls $RTPATH`;
    my $RTFILE; my @BATCHSEEN;
    foreach $RTFILE (@RTFILELIST) {
        (my $WIRE, my $RTDATE, my $RTTIME, my $WF_ID) = split /_/, $RTFILE;
		if (grep /$WF_ID$/, @BATCHLIST) {  push @BATCHSEEN, $RTFILE; }
    }
    # So now my @BATCHSEEN contains the lines that match correspondingly 
    my @MISSING = (); # answer table for missing RTFILES
    my %SEEN = ();  # lookup table to test membership of @BATCHSEEN
    my $I;
    # Build lookup table
    foreach $I (@BATCHSEEN) { $SEEN{$I} = 1; }
    # find elements in @RTFILELIST not in @BATCHSEEN
    foreach $I (@RTFILELIST) {
	unless ($SEEN{$I}) {
	    push (@MISSING, $I);
	}
    }
    Et_Run_Log ("The following files are missing corresponding entries in the BATCH file:\n @MISSING");
} 
       

