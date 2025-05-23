#!/usr/bin/perl

# wrapper to allow secuity group (SOC) to unsuspend a user on scooby

use strict;
use User::pwent;
die "Usage: $0 username\n" unless $ARGV[0];
my $user = $ARGV[0];
my $pw = getpwnam($user);
my $uid = $pw->uid;
die "Uid $uid is not < 500. Not changing.\n" if $uid <= 500;
print "Un-suspending $user\n";
exec ("/usr/bin/sudo","/usr/sbin/usermod","-s","/bin/bash","-U",$user);
