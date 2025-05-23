#!/usr/bin/perl

# quick and dirty script to allow the soc to list users (and groups)

# main code - no need to edit below here
use strict;
use User::grent;
use User::pwent;

$|=1;
my $opt = &get_args(\@ARGV);
my $group = undef;
if ($opt->{group}) { $group = &readgroup; }
if ($opt->{user}) {
   &readinfo(getpwnam($opt->{user}));
} else {
   while (my $pw = getpwent) {
      &readinfo($pw);
   }
}

# subroutines
sub readinfo {
   my $pw = shift;
   next unless $pw->uid >= 500;
   next unless $pw->uid < 65534;
   my $user = $pw->name; my $info = $pw->gecos;
   $info =~ tr/|/@/;
   my $string = sprintf "%s (%s) ", $user,$info;
   my $end = defined $group ? exists $group->{$user} ? "Groups: " . join(",",@{$group->{$user}}) . "\n" : "\n" : "\n" ;
   $string .= $end;
   print $string;
}

sub readgroup {
   my $grouphash = {};
   while (my $gr = getgrent) {
      foreach my $name (@{$gr->members}) {
         push @{$grouphash->{$name}}, $gr->name;
      }
   }
   return $grouphash;
}
sub get_args {
   my $args = shift;
   my $return = {};
   while (my $arg = shift @$args) {
      if ($arg eq '-g') {
         $return->{group} = 1;
      } elsif ($arg eq '-u') {
         my $uname = shift @$args or &help;
	 $return->{user} = $uname;
      }else { &help; }
   }
   return $return;
}

sub help {
   die <<MSG;
$0 : script to list users and groups
Usage:  userlist [-g] [-u username]
Options: 
	-g will also contain group information
	-u will show listing for only one user
MSG
}
