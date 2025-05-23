#!perl -w

use strict;
use DBI;
my $DBMH = DBI->connect('DBI:mysql:Interland__Servers__;hermes.corp.interland.net:3306','servers','N6ix$Vkn9') or die "connecting : $DBI::errstr\n";
    my $OASISPULL = $DBMH->prepare("select PhysicalName,PrimaryIP,Status,Webstatus name from Oasis__Active__ where Oasis__Active__.PhysicalName = 'IPSWAG0006ATL2'"); 
    $OASISPULL->execute();
    ((my $PN, my $IP, my $STAT, my $WEBSTAT)=$OASISPULL->fetchrow_array);
    print "$PN,$IP,$STAT,$WEBSTAT\n";


