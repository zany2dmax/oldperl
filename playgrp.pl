#!/usr/bin/perl -w

use strict;
use Tie::File;

my @GRP;

open GRPFILE, "< /etc/group" or die "Can't open /etc/group:$!\n";
while (<GRPFILE>) { push @GRP, $_; } close GRPFILE;
foreach my $LINE ( @GRP ) {
   if ($LINE =~ /daemon/) { 
       (my $GRPNAME, my $JUNK, my $GID, my $USERS) = split /:/, $LINE; 
       print "$GRPNAME\n";
   }
}
