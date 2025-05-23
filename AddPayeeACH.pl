#!/etrade/pkgs/linux/intel/perl/5.8.0/bin/perl -w
#
# AddPayeeACH.pl - gets the information for the Cyota upload for daily ACH
# transactions.  See the DailyBatch.doc for the logic of the SQL
#
# 7/18/06-7/20/06 Jeff Leggett using subroutines by Josh Forester
#
use strict;
use et_db;
use Env;
use lib "/etrade/pkgs/linux/intel/bfw_core/2.7.2/lib/";
use Time::Local;
use Date::Calc qw(Add_Delta_Days);

sub GetOldRoutingNumber {
    my $finInst = $_[0];
    my $dbh = $_[1];
    my $oldRoutingNum = "default";

    my $sql = "SELECT cmod.Attrib_Value LE_ROUTING_NUM FROM UsLegalEntityDB..CM_Organization_Detail cmod WHERE cmod.Legal_Entity_Id = $finInst AND cmod.Attrib_Type = 'ROUTING_NUM'";

    # output to xml
    my $response = et_db::output_select_to_xml ($dbh, $sql, "OLD_ROUTING_CODE");#    print "$response\n";
    if ($response =~ m/.*<LE_ROUTING_NUM>(.*)<\/LE_ROUTING_NUM>.*/) {
        my $leRoutingNum = $1;
#       print "LE_ROUTING_NUM:\t$leRoutingNum\n";
        $oldRoutingNum = $leRoutingNum;
    } else {
        my $sql2 = "SELECT cmod.Attrib_Value SWIFT_CODE FROM UsLegalEntityDB..CM_Organization_Detail cmod WHERE cmod.Legal_Entity_Id = $finInst AND cmod.Attrib_Type = 'SWIFT_CODE'";

        # output to xml

	my $response2 = et_db::output_select_to_xml ($dbh, $sql2, "OLD_SWIFT_CODE");
#        print "$response2\n";
        $response2 =~ m/.*<SWIFT_CODE>(.*)<\/SWIFT_CODE>.*/;
        my $swiftCode = $1;
#        print "SWIFT_CODE:\t$swiftCode\n";

        if ($swiftCode !~ m/^$/) {
            $oldRoutingNum = $swiftCode;
        }
    }

    return $oldRoutingNum;
}

sub GetNewerRoutingNumber {

    my $oldRoutingNum = $_[0];
    my $dbh = $_[1];
    my $newerRoutingNum = "default";

    my $sql = "SELECT cmrx.NewRoutingNo NEW_ROUTING_NUM FROM UsLegalEntityDB..CM_Routing_Xlation cmrx WHERE cmrx.OldRoutingNo = \"$oldRoutingNum\"";

    # output to xml
    my $response = et_db::output_select_to_xml ($dbh, $sql, "NEWER_ROUTING_CODE");
#    print "$response\n";
    if ($response =~ m/.*<NEW_ROUTING_NUM>(.*)<\/NEW_ROUTING_NUM>.*/) {
        my $newRoutingNum = $1;
#        print "NEW_ROUTING_NUM:\t$newRoutingNum\n";

        my $sql2 = "SELECT cmrx.Status STATUS FROM UsLegalEntityDB..CM_Routing_Xlation cmrx WHERE cmrx.OldRoutingNo = \"$oldRoutingNum\"";

        # output to xml
        my $response2 = et_db::output_select_to_xml ($dbh, $sql2, "NEWER_STATUS");
#        print "$response2\n";
        $response2 =~ m/.*<STATUS>(.*)<\/STATUS>.*/;
        my $status = $1;
#        print "STATUS:\t$status\n";

        if (($newRoutingNum !~ m/^$/) &&
            ($status =~ m/^0$/)) {
            $newerRoutingNum = $newRoutingNum;
        }
    }

    return $newerRoutingNum;
}
#
# Setup all the vars we need from the etrade environment
#
my $LOGICAL_DBNAME = "UsAccountDB_rpt";
my $LOGICAL_DBSERVER = "USDTPRD";
my $ETENV=$ENV{"ET_ENVIRONMENT"};

# Comment the following for PRD, and uncomment the line after
#my $ET_INSTANCE_ROOT="/etrade/home/jleggett";
my $ET_INSTANCE_ROOT=$ENV{"ET_INSTANCE_ROOT"};
$ENV{"WSNADDR"}=`/etrade/bin/etproperties -p WSNADDR`;
my $WSNADDR=$ENV{"WSNADDR"};
my $ET_LOGICAL_HOST=`/etrade/bin/etproperties -p DB_DOMAIN`;
chomp($ET_LOGICAL_HOST);
$ENV{"ET_LOGICAL_HOST"}=$ET_LOGICAL_HOST;
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
unless ($USACCOUNTDB_DBSVR && $USACCOUNTDB_DBNAME && $USACCOUNTDB_DBUSER && $USACCOUNTDB_DBPASSWD ) { die "Could not get USACCOUNTDB information\n"; }
#
# Open a connection to the DB
#
my $DBH = et_db::connect_to_sybase($USACCOUNTDB_DBSVR,  $USACCOUNTDB_DBNAME , $USACCOUNTDB_DBUSER , $USACCOUNTDB_DBPASSWD);
unless (defined $DBH) { die "Could not connect to USACCOUNTDB\n."; }
#
# Setup my DATE data, for Epoch (UTC) time and for managing the file 
# structure under the cyota directories
#
my $TD = (localtime)[3];
my $TM = (localtime)[4];
my $TY = (localtime)[5]+1900;
(my $YY, my $YM, my $YD) = Add_Delta_Days($TY, $TM, $TD, -1);
my $YESTSTART = timelocal(0,0,0,$YD,$YM,$YY);
my $YESTEND = timelocal(59,59,23,$YD,$YM,$YY);
# 
# Adding 1 to Month since it started counting by 0 which we needed to calculate
# Epoch (UTC) but not for Human readable directory structure and Cyota
# header Info
#
$YM++;
#
# Setup our output directory structure
#
#
# Our RAW data will be written here in this section.
#
my $RAWDATADIR=$ET_INSTANCE_ROOT . "/logs/cyota/$YY/$YM/$YD";
`mkdir -p $RAWDATADIR`;
open my $ADDPAYEEFILE , ">$RAWDATADIR/addpayee.$YD$YM$YY.raw" or die "Unable to open Add Payee RAW file\n";
#
# Send it to the DB and execute the SQL
#
my $ADDPAYEESQL = "select ea.UserId USER_ID, ea.AccountId ACCOUNT_ID, ea.InstNo INST_ID, ea.CreateDT OPEN_DATE from acct_ExtAccount ea where ea.CreateDT > $YESTSTART and ea.CreateDT < $YESTEND";
my $ADDPAYEEPULL = $DBH->prepare($ADDPAYEESQL);
$ADDPAYEEPULL->execute();
#
# main processing loop
#
my $ROWCOUNT=0;
print $ADDPAYEEFILE "#event_type|user_id|account_id|routing_num|activity_time\n";
while ((my $USERID, my $ACCOUNTID, my $INSTID, my $OPENDATE) = $ADDPAYEEPULL->fetchrow_array) {
	my $GETROUTINGNUM = GetOldRoutingNumber($INSTID, $DBH);
	my $FINAL_ROUTING_NUM = $GETROUTINGNUM;
	my $DONE = "false";
	my $NEWROUTINGNUM = "default";
	while ($DONE eq "false") {
		$NEWROUTINGNUM = GetNewerRoutingNumber($GETROUTINGNUM, $DBH);
		if ($NEWROUTINGNUM eq "default") { $DONE = "true"; } 
		else { $FINAL_ROUTING_NUM = $NEWROUTINGNUM; }
	}
	$ROWCOUNT++;
	print $ADDPAYEEFILE "add_payee|$USERID|$ACCOUNTID|$FINAL_ROUTING_NUM|$OPENDATE\n";
}
print $ADDPAYEEFILE "#$ROWCOUNT\n";
close $ADDPAYEEFILE;
