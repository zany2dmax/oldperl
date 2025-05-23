#!/usr/bin/perl

# script to modify user groups
# designed to be called from fish.pl, but could also be used directly (sudo)
# arguments -u user -a gid[,gid,...] -d gid[,gid,...]

use strict;
# options
my %options = (
   'verbose' => 1,	# weather verbose output is on or off
);

# main code ... no need to modify below here
$|=1;
if ($< != 0) { die "Sorry. You must be root to run $0\n"; }

# get arguments
my $in = &get_args(\@ARGV);

# delete user from groups
if (scalar @{$in->{del}} > 0) {
   if ($options{verbose}) { print "Removing group(s) for user $in->{user}\n";}
   &modgroup('-d',$in->{user},$in->{del});
}
# add user to groups
if (scalar @{$in->{add}} > 0) {
   if ($options{verbose}) { print "Adding group(s) for user $in->{user}\n";}
   &modgroup('-a',$in->{user},$in->{add});
}

# subroutines
sub modgroup {
   my ($action,$user,$groups) = @_;
   my @command = ("/usr/bin/gpasswd",$action,$user);
   foreach my $group (@$groups) {
      my $name = (getgrgid($group))[0];
      #if ($options{verbose}) { print "$action group $group($name)\n"; }
      system @command, $name;
   }
}

sub get_args {
   my $args = shift;
   my ($user,@add,@del) = undef;
   while (my $arg = shift @$args) {
      if ($arg eq '-u') {
         $user = shift @$args;
      } elsif ($arg eq '-a') {
         my $addlist = shift @$args;
	 @add = split /,/,$addlist;
      } elsif ($arg eq '-d') {
         my $dellist = shift @$args;
	 @del = split /,/,$dellist;
      } else {
         print STDERR "Invalid argument $arg\n\n";
         &help;
      }
   }
   unless ($user && (scalar @add > 0 || scalar @del > 0)) {
      print STDERR "Missing action.\n\n";
      &help;
   }
   return {'user'=>$user,'add'=>\@add,'del'=>\@del};
}

sub help {
   die <<MSG;
$0 : script to modify user groups
Description: designed to be called from fish.pl, but could also
             be used directly (via sudo)
Usage: 	$0 -u user {-a gid[,gid,...] | -d gid[,gid,...]}
MSG
}
