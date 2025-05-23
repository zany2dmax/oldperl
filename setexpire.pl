#!/usr/bin/perl

# simple script to set password expire times for users

# main
use strict;
use Linux::usermod;

my $arg = &getargs(\@ARGV);
my $mod = Linux::usermod->new($arg->{'username'});
if ($arg->{expire} && $arg->{disable}) {
# find out how many days since last change
   my $last = $mod->show('dsalch');
   my $nowday = int(time() / 86400);
   my $exdelta = ($nowday - $last) + $arg->{expire}; 
# modify new expire times
   $mod->change('must',$exdelta);
   $mod->change('expire',$arg->{disable});
   print "Modified /etc/shadow for $arg->{username}\n";
}

my ($uexp,$udis,$last) = ($mod->show('must'),$mod->show('expire'),$mod->show('dsalch'));
my $nowday = int(time() / 86400);
my $cdif = $nowday - $last;
my $willexp = $uexp - $cdif;
printf STDOUT "Password for %s last changed %d days ago, and will expire in %d days.\n Disable time set to %d days after password expiration.\n", $arg->{username},$cdif,$willexp,$udis;

# subroutines

sub help {
   die <<USAGE;
Usage: $0 [-u username] [-e days] [-d days] [-s]
Options:
-u username	Username
-e days 	Days until password expires
-d days 	Days after which password expires that account will be disabled
-s		Displays expiration dates for user
USAGE
}

sub getargs {
   my $args = shift;
   my ($username,$expire,$disable,$show) = ();
   while (my $arg = shift @$args) {
      if ($arg eq '-u') {
         $username = shift @$args;
         unless ($username =~ /^\w+$/) {
            warn "Invalid username '$username'!\n";
            &help;
         }
      } elsif ($arg eq '-e') {
         $expire = shift @$args;
         unless ($expire =~ /^\d+$/) {
            warn ("$expire is not a valid expire days number\n");
            &help;
         }
      } elsif ($arg eq '-d') {
         $disable = shift @$args;
	 unless ($disable =~ /^\d+$/) {
            warn ("$disable is not a valid exipre days number\n");
            &help;
         }
      } elsif ($arg eq '-s') {
         $show = 1;
      } else {
         print STDERR "Invalid Argument \"$arg\"\n";
	 &help;
      }
   }
   unless ($username) {
      print "Enter Username: ";
      chomp ($username = <STDIN>);
      die "invalid input!\n" unless $username;
   }
   unless ($expire || $show) {
      print "How many days until password expires [60]: ";
      chomp ($expire = <STDIN>);
      $expire ||= 60;
   }
   unless ($disable || $show) {
      print "How many days after password expire until disabled [4]: ";
      chomp ($disable = <STDIN>);
      $disable ||= 4;
   }
   return {'username'=>$username,'disable'=>$disable,'expire'=>$expire,'show'=>$show};
}

