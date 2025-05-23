#!/etrade/pkgs/linux/intel/perl/5.8.0/bin/perl -w
#
# getIntlWireData.pl - A program to generate the Cyota fraud reports
# for ACH transactions(?)

use strict;
use DBI;
use Env;
Env::import();
#use Getopt::Long;
use et_db;
use lib "/etrade/pkgs/linux/intel/bfw_core/2.7.2/lib/"; 
use Date::Calc qw(Add_Delta_Days);
#
# Get yesterdays Date - DB not using normal DATETIME variable encoding, so 
# this munging needed to match in SQL
#
my %MONTHCONV = (
        1 => "Jan ", 2 => "Feb ", 3 => "Mar ", 4 => "Apr ", 5 => "May ",
        6 => "Jun ", 7 => "Jul ", 8 => "Aug ", 9 => "Sep ", 10 => "Oct ",
        11 => "Nov ", 12 => "Dec "
);
my %DAYCONV = (
        1 => " 1 ", 2 => " 2 ", 3 => " 3 ", 4 => " 4 ", 5 => " 5 ",
        6 => " 6 ", 7 => " 7 ", 8 => " 8 ", 9 => " 9 ", 1  => "1  ",
        11 => "11 ", 12 => "12 ", 13 => "13 ", 14 => "14 ", 15 => "15 ",
        16 => "16 ", 17 => "17 ", 18 => "18 ", 19 => "19 ", 20 => "20 ",
        21 => "21 ", 22 => "22 ", 23 => "23 ", 24 => "24 ", 25 => "25 ",
        26 => "26 ", 27 => "27 ", 28 => "28 ", 29 => "29 ", 30 => "30 ",
        31 => "31 "
);
my $TD = (localtime)[3];
my $TM = (localtime)[4]+1;
my $TY = (localtime)[5]+1900;
(my $YY, my $YM, my $YD) = Add_Delta_Days($TY, $TM, $TD, -1);
my $DATESTRING = $MONTHCONV{"$YM"} . $DAYCONV{"$YD"} . $YY;
#
#
# Setup all the vars we need from the etrade environment
#
my $LOGICAL_DBNAME = "UsAccountDB_rpt";
my $LOGICAL_DBSERVER = "USDTPRD";
my $ETENV=$ENV{"ET_ENVIRONMENT"};

open LOG , ">$ET_INSTANCE_ROOT/logs/getIntlWireData.$TY$TM$TD" or die "Can't open LOGFILE!\n";

# Comment the following for PRD, and uncomment the line after
#my $ET_INSTANCE_ROOT="/etrade/home/jleggett";
my $ET_INSTANCE_ROOT=$ENV{"ET_INSTANCE_ROOT"};
$ENV{"WSNADDR"}=`/etrade/bin/etproperties -p WSNADDR`;
my $WSNADDR=$ENV{"WSNADDR"};
print LOG "$WSNADDR\n";
my $ET_LOGICAL_HOST=`/etrade/bin/etproperties -p DB_DOMAIN`;
chomp($ET_LOGICAL_HOST);
$ENV{"ET_LOGICAL_HOST"}=$ET_LOGICAL_HOST;
print LOG "$ET_LOGICAL_HOST\n";
if (!$WSNADDR) { print LOG "WSNADDR not set\n"; close LOG; exit; }
if (!$ET_LOGICAL_HOST) {
    print LOG "ET_LOGICAL_HOST not set\n";
    close LOG;
    exit;
}

my $USACCOUNTDB_DBSVR="";
my $USACCOUNTDB_DBNAME="";
my $USACCOUNTDB_DBUSER="";
my $USACCOUNTDB_DBPASSWD="";
#
# This checks if we're in a DEV environment or not
#
if ($ETENV eq "dev") {
	$USACCOUNTDB_DBSVR="UATUSS5";
	$USACCOUNTDB_DBNAME="UsAccountDB";
	$USACCOUNTDB_DBUSER="tuxuser";
	$USACCOUNTDB_DBPASSWD="tuxedo";
}
else {
	($USACCOUNTDB_DBSVR,$USACCOUNTDB_DBNAME,$USACCOUNTDB_DBUSER,$USACCOUNTDB_DBPASSWD) = et_db::get_db_info($LOGICAL_DBNAME, $LOGICAL_DBSERVER);
}

# Uncomment following for debugging
print LOG "USACCOUNTDB Connection Details : $USACCOUNTDB_DBSVR,  $USACCOUNTDB_DBNAME , $USACCOUNTDB_DBUSER\b.";
unless ($USACCOUNTDB_DBSVR && $USACCOUNTDB_DBNAME && $USACCOUNTDB_DBUSER && $USACCOUNTDB_DBPASSWD ) { die "Could not get USACCOUNTDB information\n"; } 
#
# open a connection to the DB
#
my $DBH = et_db::connect_to_sybase($USACCOUNTDB_DBSVR,  $USACCOUNTDB_DBNAME , $USACCOUNTDB_DBUSER , $USACCOUNTDB_DBPASSWD);
unless (defined $DBH) 
{
    die "Could not connect to USACCOUNTDB\n.";
}
#
# Our RAW data will be written here in this section.  
#
my $RAWDATADIR=$ET_INSTANCE_ROOT . "/logs/cyota/$YY/$YM/$YD";
print LOG ".raw File directory is: $RAWDATADIR\n";
`mkdir -p $RAWDATADIR`;
open my $INTL_WIRE , ">$RAWDATADIR/intlwiredata.raw" or die "Unable to open Intl Wire RAW file\n";

# And the SQL query itself 
#
my $INTLWIRESQL="select t2.acct_no,t2.link_acct_no,t2.link_inst_no,t3.profile_name,t3.profile_value, t4.Legal_Entity_Id,rtrim(t4.Attrib_Type),t4.Attrib_Value, convert(varchar,t3.Ts,112)+convert(varchar,t3.Ts,108) from acct_Relation t2,acct_Profile t3, UsLegalEntityDB..CM_Organization_Detail t4 where t2.link_acct_no=t3.acct_no and t2.link_inst_no=t3.inst_no and t3.inst_no=t4.Legal_Entity_Id and t4.Attrib_Type= 'SWIFT_CODE' and (t3.profile_name like '%ACCT_WIRE_INSTRUCTION' or t3.profile_name like '%BANK_NAME' or t3.profile_name like '%CUST_NAME') and t3.Ts >= '$DATESTRING 12:00AM' and t3.Ts <= '$DATESTRING 11:59PM'";

print "Running this SQL: $INTLWIRESQL\n";
my $IWROWS = et_db::output_select_to_filehandle ($DBH, $INTLWIRESQL, $INTL_WIRE, "|");
if ($IWROWS >= 0) {print LOG "All good!  $IWROWS rows returned\n"; }
else { print LOG "Not good!  $IWROWS\n"; }
close $INTL_WIRE;
close LOG;
