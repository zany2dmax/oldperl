#!/etrade/pkgs/linux/intel/perl/5.8.0/bin/perl -w

use strict;
use Date::Calc qw(Add_Delta_Days);
my $TD = (localtime)[3];
my $TM = (localtime)[4]+1;
my $TY = (localtime)[5]+1900;
(my $YY, my $YM, my $YD) = Add_Delta_Days($TY, $TM, $TD, -1);

