#!/usr/bin/perl

# wrapper to allow secuity group (SOC) to suspend a user on scooby

use strict;
use User::pwent;
die "Usage: $0 username\n" unless $ARGV[0];
my $user = $ARGV[0];
my $pw = getpwnam($user);
my $uid = $pw->uid;
die "Uid $uid is not < 500. Not suspending.\n" if $uid <= 500;
print "Suspending $user\n";
exec ("/usr/bin/sudo","/usr/sbin/usermod","-s","/sbin/nologin","-L",$user);
