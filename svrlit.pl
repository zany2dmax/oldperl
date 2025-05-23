#!/usr/bin/perl -w

open (INFILE, "pl-winlist.csv") or die "File not found\n";
while (<INFILE>) {
    ($COMPNAME,$REST) = split /,/,$_,2;
    $COMPNAME =~ s/"\\\\(\w+)"//g; # strip the double quotes and forward slashes
    #push the regexed computername to an array and make lower case 
    push(@INSTALLED,lc $COMPNAME); 
}
close INFILE;
#open (INFILE, "windows.servers.csv") or die "File not found\n";
open (INFILE, "shared.svrs") or die "File not found\n";
while (<INFILE>) {
    ($COMPNAME,$REST) = split /,/,$_,2;
    push(@SNITCHLIST, [ $COMPNAME, $REST ] );
}
close INFILE;
# We now have two arrays of servers.  @INSTALLED is a list of servers with 
# the PL agent installed and @SNITCHLIST is a list of servers from SNITCH.
# Now we want to remove any that are in @INSTALLED from @SNITCHLIST leaving
# a list that does not have PL installed.

%SEEN = ();
@SNITCHONLY = ();
foreach $COMPUTER (@INSTALLED) { $SEEN{$COMPUTER} = 1 };
foreach $COMPUTER (@SNITCHLIST) { 
    unless ($SEEN{$COMPUTER}) { push(@SNITCHONLY,$COMPUTER) }
}

# Now @SNITCHONLY contains the list of servers without PL intalled

foreach $COMPUTER (@SNITCHONLY) { print "$COMPUTER\n"; }
