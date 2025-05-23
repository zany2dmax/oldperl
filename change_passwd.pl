#!/etrade/pkgs/opensrc/1.0/bin/perl5.6.1 -w 

BEGIN { 
$ET_DBMON_ROOT=$ENV{'ET_DBMON_ROOT'}; 
$ET_SYBPERL_ROOT=$ENV{'ET_SYBPERL_ROOT'}; 
#@myperlib = ("$ET_DBMON_ROOT/lib", "/ANOTHER_LIB/lib"); 
@myperlib = ("$ET_DBMON_ROOT/lib", "$ET_SYBPERL_ROOT/lib"); 
} 

use lib @myperlib; 
use Profile; 

########################## 
## Set Common Variables ## 
########################## 
StandardVars; 

## End autoheader 

#######################################################################################
#                     Li Yang <li.yang@etrade.com>
#                    Staff, Database Administration
#                     Data Services Infrastructure
#
#  Usage
#  =====
#  perl ./change_passwd.pl <sybd.ini> <sybd.psw> 
#    e.g.
#  perl ./change_passwd.pl sybd.ini
#
#  Description
#  ===========
#  Using dba login "etsybsa", Changes the password for a particular login across all
#  dataservers. The program will prompt the user for the following info:
#
#  - login whose password will be changed
#  - the new password for that login
#
#  With this info, the program will open the ini file to get the list of
#  dataservers starting with string "sql1". Note: the sybd.ini file expects the
#  following format:
#
#  sql1:<dataserver>:<machine>
#
#  Then the program will retrieve the password for "etsybsa" by searching the sybd.psw
#  file, whose format is:
#
#  <dataserver>:<password>
#
#  After attempting to reset the password on each dataserver, it prints an appropriate
#  message stating whether it failed, succeeded, or login does not exist.
#
#  History
#  =======
#  10/18/04 (Li Yang): First version
#  12/30/04 (Jack Forester): Adapted to be dbmon package friendly
#		Added HEADER info at top which is expanded with perl version and
#		standard variables.  Default config files to cfgdir.
#######################################################################################

##Replaced by HEADER at top which is expanded during make install to allow for 
## easy changes in the future-JBF#!/usr/bin/perl

use strict;
use warnings;


$| = 1;             # immediately print message


#######################################################################################
# Parameters: sql statement
# Description: Runs a sql query against a dataserver. No rowcount is returned in the
#              results and the "Password:" output is removed. 
# Return Val: result of query
#######################################################################################
sub ExecuteSql
{
    my $sql;
    my $dbsvr;
    my $dba_passwd;
    my $dba_login;
    my ($cmd, $result);
    
    ($sql, $dbsvr, $dba_login, $dba_passwd) = @_;
    
    $cmd  = "isql -S$dbsvr -U$dba_login -Dmaster -X -b -n <<END\n";
    $cmd .= "$dba_passwd\n";
    $cmd .= "$sql\n";
    $cmd .= "END";
    
    $result = `$cmd`;
    if ($? != 0) {
        print LOGFILE "Warning: failed to run 'isql -S$dbsvr -U$dba_login -X -b -n' !\n";
    }
    
    $result =~ s/Password://i;  # remove the "Password:" string echoed to console
    if ($result =~ /Msg.*?Level.*?State/) {
        print LOGFILE "Warning: sql query returned the following error\n\n$result\n";
    }
    return($result);
} # end sub ExecuteSql

sub ExecuteRepSql
{
    ##
    ## Needed because can't use -X option with pre 12.6 Rep Servers ##
    ## Needed because can't use -D option with Rep Servers ##
    ## JBF
    ##
    my $sql;
    my $repsvr;
    my $dba_passwd;
    my $dba_login;
    my ($cmd, $result);
    
    ($sql, $repsvr, $dba_login, $dba_passwd) = @_;
    
    $cmd  = "isql -S$repsvr -U$dba_login -b -n <<END\n";
    $cmd .= "$dba_passwd\n";
    $cmd .= "$sql\n";
    $cmd .= "END";
    
    $result = `$cmd`;
    if ($? != 0) {
        print LOGFILE "Warning: failed to run 'isql -S$repsvr -U$dba_login -X -b -n' !\n";
    }
    
    $result =~ s/Password://i;  # remove the "Password:" string echoed to console
    if ($result =~ /Msg.*?Level.*?State/) {
        print LOGFILE "Warning: sql query returned the following error\n\n$result\n";
    }
    return($result);
} # end sub ExecuteRepSql


#######################################################################################
############                        Main Program
#######################################################################################

my $sql;
my $result;
my ($file_ini, $file_psw);
my $dbsvr;
my $repsvr;
my $dba_login = "etsybsa";
my $dba_passwd;
my ($login, $newpasswd, $newpasswd2);
my @dbservers = ();
my @repservers = ();
my %dbsvr_pass = ();

if ($#ARGV != 1) {
    print STDERR "\nUsage: perl $0 <sybd.ini> <sybd.psw>\n\n";
    print STDERR "\nExpects files to be in $ET_INSTANCE_ROOT/config\n\n";
    exit(1);
}

$file_ini = $ARGV[0];
$file_psw = $ARGV[1];

if (-e "/tmp/change_password.out") {
    open (LOGFILE, "+</tmp/change_password.out.$$") or die "Error " . __FILE__ . ": Line:" .  __LINE__ . ": Could not open file /tmp/change_password.out.$$!\n"; flock(LOGFILE, 2);
} else {
    open (LOGFILE, "+>/tmp/change_password.out.$$") or die "Error " . __FILE__ . ": Line:" .  __LINE__ . ": Could not create file /tmp/change_password.out.$$!\n"; flock(LOGFILE, 2);
}


#
# prompt user for login & new password
#
print "Enter the login whose password will be changed: ";
$login = <STDIN>;
chomp($login);
die "Error: invalid login!\n" if (length($login)<1);
print "Enter the new password for login '$login': ";
system("stty -echo") && die "\nError: failed to turn off echo!\n"; # don't show password in console
$newpasswd = <STDIN>;
chomp($newpasswd);
system("stty echo") && die "\nError: failed to turn on echo!\n";  # show text in console
die "Error: invalid password! Must be at least 8 chars.\n" if (length($newpasswd)<8);
die "Error: invalid password! Must be 8 to 30 chars.\n" if (length($newpasswd)>30);
print "\nRe-enter the new password for login '$login': ";
system("stty -echo") && die "\nError: failed to turn off echo!\n";
$newpasswd2 = <STDIN>;
chomp($newpasswd2);
system("stty echo") && die "\nError: failed to turn on echo!\n";
print "\n\n";

if ($newpasswd ne $newpasswd2) {
    die "Error: new passwords don't match!\n";
}

print STDERR "Output being logged here: /tmp/change_password.out.$$\n";

#
# get list of dataservers from sybd.ini file and grab corresponding
# list of passwords from sybd.psw
#
$result = `grep "^sql1:" $cfgdir/$file_ini | cut -d":" -f2`;
@dbservers = split(/\n/, $result);
foreach $dbsvr (@dbservers) {
    next if ($dbsvr =~ /\s+/);    # skip non dataserver entries
    $result = `grep "^$dbsvr:" $cfgdir/$file_psw | cut -d":" -f2 | line`;  # get password
    chomp($result);
    if (!defined($result) || length($result)<1) {   # verify password existance
        print LOGFILE "Warning: failed to get password for dataserver '$dbsvr'!\n";
        next;
    }
    $dba_passwd = $result;
    
    # construct sql query for locator entry
    $sql =<<ENDSQL;
if exists (select 1 from master..syslogins where name = "$login")
   exec master..sp_password "$dba_passwd", "$newpasswd", "$login"
else
   print 'login "$login" does not exist' 
go
ENDSQL

    print LOGFILE "\n\nChanging password on dataserver '$dbsvr'\n";
    $result = ExecuteSql($sql, $dbsvr, $dba_login, $dba_passwd);
    if ($result =~ /Password correctly set/i) {
        print LOGFILE "password successfully reset\n";
    }
    elsif ($result =~ /not exist/i) {
        print LOGFILE "$result\n";
    }

} # end foreach

#
# get list of repservers from sybd.ini file and grab corresponding
# list of passwords from sybd.psw
#
$result = `grep "^sqlr1:" $cfgdir/$file_ini | cut -d":" -f2`;
@repservers = split(/\n/, $result);
foreach $repsvr (@repservers) {
    next if ($repsvr =~ /\s+/);    # skip non dataserver entries
    $result = `grep "^$repsvr:" $cfgdir/$file_psw | cut -d":" -f2 | line`;  # get password
    chomp($result);
    if (!defined($result) || length($result)<1) {   # verify password existance
        print LOGFILE "Warning: failed to get password for Rep Server '$repsvr'!\n";
        next;
    }
    $dba_passwd = $result;
    
    # construct sql query for locator entry
    $sql =<<ENDSQL;
alter user "$login" set password "$newpasswd"
go
ENDSQL

    print LOGFILE "\n\nChanging password on Rep Server '$repsvr'\n";
    $result = ExecuteRepSql($sql, $repsvr, $dba_login, $dba_passwd);
    if ($result =~ /is altered/i) {
        print LOGFILE "password successfully reset\n";
    }
    elsif ($result =~ /doesn't exist/i) {
        print LOGFILE "$result\n";
    }

} # end foreach

close (LOGFILE);
print STDERR "Log file created here: /tmp/change_password.out.$$\n\n";

exit(0);
