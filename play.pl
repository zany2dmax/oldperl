#!/usr/bin/perl -w

use strict;

my $MAIL = undef;

if ( -e "/bin/mail" ) { $MAIL = "/bin/mail"; }
elsif ( -e "/usr/bin/mail" ) { $MAIL = "/usr/bin/mail"; }

print $MAIL,"\n";
