#!/usr/bin/perl -w

use strict;

open STUPIDFILE, " < AccountID.csv";
open NEWDUMBER, " >bigline";
while (<STUPIDFILE>) {
    chop;
    print NEWDUMBER "$_, ";
}
print NEWDUMBER "\n";
close STUPIDFILE;
close NEWDUMBER;
    
