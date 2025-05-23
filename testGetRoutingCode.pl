#!/etrade/pkgs/linux/intel/perl/5.8.0/bin/perl -w
#
# play code to get the routing code from the
# financial inst. number
#

use strict;
use DBI;
use Env;
Env::import();
use Date::Calc qw(:all);
use et_db;
use lib "/etrade/pkgs/linux/intel/bfw_core/2.7.2/lib/"; 

#
#
# Setup all the vars we need fromt he etrade environment
#
my $logicalDBName = "UsAccountDB_rpt";
my $logicalDBServer = "USDTPRD";
my $inst = "68095050";
#my $inst = "2583751019";
#my $inst = "236203050";

my $etEnv = $ENV{"ET_ENVIRONMENT"};

# Comment the following for PRD, and uncomment the line after
$ENV{"WSNADDR"} = `/etrade/bin/etproperties -p WSNADDR`;
my $wsnAddr = $ENV{"WSNADDR"};
my $etLogicalHost = `/etrade/bin/etproperties -p DB_DOMAIN`;
chomp($etLogicalHost);
$ENV{"ET_LOGICAL_HOST"} = $etLogicalHost;
if (!$wsnAddr) { exit; }
if (!$etLogicalHost) { exit; }

my $dbServer="";
my $dbName="";
my $dbUser="";
my $dbPassword="";
#
# This checks if we're in a DEV environment or not
#
if ($etEnv eq "dev") {
	$dbServer = "UATUSS5";
	$dbName = "UsAccountDB";
        $dbUser = "tuxuser";
	$dbPassword = "tuxedo";
}
else {
	($dbServer,$dbName,$dbUser,$dbPassword) = et_db::get_db_info($logicalDBName, $logicalDBServer);
}


sub GetOldRoutingNumber {
    my $finInst = $_[0];
    my $dbh = $_[1];
    my $oldRoutingNum = "default";

    my $sql = "SELECT cmod.Attrib_Value LE_ROUTING_NUM FROM UsLegalEntityDB..CM_Organization_Detail cmod WHERE cmod.Legal_Entity_Id = $finInst AND cmod.Attrib_Type = 'ROUTING_NUM'";

    # output to xml
    my $response = et_db::output_select_to_xml ($dbh, $sql, "OLD_ROUTING_CODE");
#    print "$response\n";
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



# open a connection to the DB
#
my $dbh = et_db::connect_to_sybase($dbServer, $dbName , $dbUser, $dbPassword);
unless (defined $dbh) 
{
    die "Could not connect to $dbName\n.";
}

#my $leRoutingNum = "063114386";

my $leRoutingNum =  GetOldRoutingNumber($inst, $dbh);
my $finalRoutingNum = $leRoutingNum;
my $newRoutingNum = "default";
my $done = "false";

while ($done =~ m/^false$/) {
    $newRoutingNum = GetNewerRoutingNumber($finalRoutingNum, $dbh);
  
    if ($newRoutingNum =~ m/^default$/) {
        $done = "true";
    } else {
       $finalRoutingNum = $newRoutingNum;
    }
}

print "Final Routing Number:\t$finalRoutingNum\n";

