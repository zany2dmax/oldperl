#!/etrade/pkgs/linux/intel/perl/5.8.0/bin/perl -w

use strict;
use DBI;
use Env;
use et_db;
use lib "/etrade/pkgs/linux/intel/bfw_core/2.7.2/lib/";
my $LOGICAL_DBNAME = "UsAccountDB_rpt";
my $LOGICAL_DBSERVER = "USDTPRD";

my $ETENV=$ENV{"ET_ENVIRONMENT"};
my $ET_INSTANCE_ROOT=$ENV{"ET_INSTANCE_ROOT"};
$ENV{'WNSADDR'}=`/etrade/bin/etproperties -p WSNADDR`;
print qq($ENV{"WNSADDR"});
my $ET_LOGICAL_HOST=`/etrade/bin/etproperties -p DB_DOMAIN`;
chomp($ET_LOGICAL_HOST);
$ENV{'ET_LOGICAL_HOST'}=$ET_LOGICAL_HOST;
print qq($ENV{"ET_LOGICAL_HOST"});
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

