#!/usr/bin/perl

# script to change user password
use strict;

my $username = undef;
if ($ARGV[0]) {
   $username = $ARGV[0];
} else {
   print "Enter Username: ";
   $username = <>;
   chomp $username;
}

my $uid = (getpwnam($username))[2] || die "User $username does not exist\n" ;
die "Uid for $username is not >= 500. Permission Denied.\n" unless $uid >= 500;


exec ("/usr/bin/passwd",$username);
