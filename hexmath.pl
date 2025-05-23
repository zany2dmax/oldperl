#!/usr/bin/perl -w 

use strict;
my $MAC = "000cdb8be518";
my @MACLIST = hexmath($MAC);
print @MACLIST;
exit;

sub hexmath {
   my $HEXNUM = @_[0];
   print "Full Mac Addr: $HEXNUM\n";
   print "Full Mac Addr: @_[0]\n";
   my $ENDMAC = substr ($HEXNUM,-4);
   print "End of Mac Addr: $ENDMAC\n";
   my $FRONTMAC = substr ($HEXNUM,0,8);
   print "Start of Mac Addr: $FRONTMAC\n";
   my $NUMBER = hex($ENDMAC);
   print "End converted to Decimal: $NUMBER\n";
   my @MACLIST;
   my $TMPN = 0;
   for (my $I = -4; $I <= 4; $I++) {
       $TMPN = $NUMBER + $I;
       # print $TMPN,"\n";
       $MACLIST[$I+4] = $FRONTMAC . (sprintf "%lx", $TMPN);
       print "$MACLIST[$I+4]\n";
   }
   return @MACLIST;
}


