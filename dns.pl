#!/usr/bin/perl

# ssh wrapper to make "super-like" wrapping of users to use
# the correct key file for their ssh commands to systems

use strict;
use User::grent;

#################
# configuration #
#################

# this is the list of groups in the /etc/group file that will be checked
# for access rights to ssh to production servers
my @grouplist = ('dns_sysad1','dns_root');
my $DEBUG = 0;
my $pfile = ".spref.dns"; # file that stores gid pref for each user
my $localhost = `/bin/hostname`;
chomp $localhost;

# hack to make dns work
my $uhash = {
	'dns_root' => 'root',
	'dns_sysad1' => 'sysad1',
};
# end hack

#################
### main ########
#################
my $args = &getargs(\@ARGV);
my $hostname = $args->{hostname};
my $ugroup = $args->{group}; # I know this is convoluted...
my $username = undef;
if ($ugroup) { $username = $uhash->{$ugroup}; }
my $uname = $args->{username};
my $uhost = ();

my @info = getpwuid($<);
my $mygroup = &usergroup(\@info);
#print "Groups for $info[0]: ", join " ", @$mygroup, "\n";

if ( defined $ugroup) {
   $uname = $uname ? "$uname\@" : "$username\@";
   $uhost = $uname . $hostname;
   my $gri = getgrnam($ugroup) or die "$ugroup is not a valid group. exiting\n";
   my $trusted = undef;
   foreach my $name (@{$gri->members}) {
      if ($name eq $info[0]) { $trusted = 1 }
   }
   if ($trusted) {
     my @command = ("/usr/bin/sudo","/usr/bin/ssh","-i","/root/.ssh/otherkeys/core/id_dsa_$ugroup",$uhost);
     printf "executing %s\n", join " ", @command if $DEBUG;
     system @command;
     die "Welcome back to $localhost, $info[0]\n";
   } else {
      die "Sorry $info[0], you do not have rights for group $ugroup\n";
   }
} elsif ( scalar(@$mygroup) > 1) {
  my $mg = &selectgroup($mygroup);
  my $mgu = $uhash->{$mg};
  $uname = $uname ? "$uname\@" : "$mgu\@";
  $uhost = $uname . $hostname;
  my @command = ("/usr/bin/sudo","/usr/bin/ssh","-i","/root/.ssh/otherkeys/core/id_dsa_$mg",$uhost);
  printf "executing %s\n", join " ", @command if $DEBUG;
  system @command;
  die "Welcome back to $localhost, $info[0]\n";
} elsif ( scalar(@$mygroup) == 1 ) {
  my $mg = $mygroup->[0];
  my $mgu = $uhash->{$mg};
  $uname = $uname ? "$uname\@" : "$mgu\@";
  $uhost = $uname . $hostname;
  my @command = ("/usr/bin/sudo","/usr/bin/ssh","-i","/root/.ssh/otherkeys/core/id_dsa_$mg",$uhost);
  printf "executing %s\n", join " ", @command if $DEBUG;
  system @command;
  die "Welcome back to $localhost, $info[0]\n";
} else {
  die "You do not have access to this command";
}

sub usergroup {
   my $data = shift;
   my $user = $data->[0];
   my @group = ();
   foreach my $node ( @grouplist ) {
      my $gr = getgrnam($node);
      foreach my $name (@{$gr->members}) {
         if ($name eq $user) { push @group, $gr->name; }
      }
   }
   return \@group;
}

sub selectgroup {
   my $groups = shift;
   # check pref file
   my $pref = undef;
   if (-f "$info[7]/$pfile") {
      open PIN, "<$info[7]/$pfile" or warn "$info[7]/$pfile not read: $!\n";
      $pref = <PIN>;
      chomp $pref;
      close PIN;
   }
   system ("/usr/bin/tput","reset") unless $DEBUG;
   print <<DIRECTIONS;
Welcome, $info[0]

To avoid this screen for future ssh calls, you can run:
$0 -g groupname [username\@]hostname	   
where groupname refers to a group listed here
DIRECTIONS

   my $correct = 0;
   my $selected;
   until ( $correct ) {
      print <<INSTRUCTIONS;

Please select your login group. The group you select will determine your
access level on the remote system.
INSTRUCTIONS
      my $num = 0; 
		my $numpref = {};
      foreach my $group (@$groups) {
			 $numpref->{$group} = $num;
          printf("[%d] %s\n", $num++, $group);
      }
      my $default = $pref ? " [$numpref->{$pref}]" : undef;
      print "Enter the number of your selection$default: ";
      chomp (my $gnum = <STDIN>);
      if ($default && ($gnum eq "")) {
         $selected = $pref; 
      } else {
         $gnum ||=0;
         $selected = $groups->[$gnum];
      }
      print "You selected $selected. Is this correct? [Yn]: ";
      chomp (my $ans = <STDIN>);
      $ans ||= 'y';
      $correct = $ans =~ /y/i ? 1 : 0; 
   } 
   open POUT, ">$info[7]/$pfile" or warn "couldn't write $info[7]/$pfile: $!\n";
   print POUT "$selected";
   close POUT;
   return $selected;
}

sub help { die "usage: $0 [-g usergroup]  [username@]hostname\n"; }

sub getargs {
   my $args = shift;
   my ($username,$hostname,$group) = ();
   while (my $arg = shift @$args) {
      if ($arg eq '-g') {
         $group = shift @$args ; 
	 next;
      }
      if ($arg =~ /^([\w.-]+\@)*([\w.-]+)$/) { 
         ($username,$hostname) = ($1,$2); 
	 $username =~ tr/@//;
	 print "D: username=\"$username\" hostname=\"$hostname\"\n" if $DEBUG;
	 next;
      }
      &help if $arg =~ /-h|--help/i;
   }
   unless ( $hostname =~ /^[\w.-]+$/) {
      warn "Invalid Hostname: \"$hostname\"\n" ;
      &help;
   }
   return {'username'=>$username,'hostname'=>$hostname,'group'=>$group};
}
