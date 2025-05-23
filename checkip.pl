#!/usr/bin/perl -w
sub isanip {
   chomp $_[0];   
   if ($_[0] !~ /^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/) { return(1); }   
   foreach $s (($1, $2, $3, $4)) {
       if (0 > $s || $s > 255) {
           return(1);
       }
    }
    return(0);
}

open (FH, "ipaddrtest");
while (<FH>) {
	print $_;
	if (isanip($_) == 0) { print "$_ is an IP.\n"; }
	else { print "$_ is NOT an IP.\n"; }
} 
close FH;
