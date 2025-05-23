#!/usr/bin/perl 

# script to verify system users with corporate domain accounts

use strict;

# defaults
my %conf = (
   'verbose' => 1,	# output verbosity... change to 0 to suppress
   'suspend-file' => '/var/tmp/domainsuspend', # default suspension file
   'suspend-now' => 1,	# if set to 1 suspends immediately, otherwise writes 
                        # output to suspend-file for 
   			# later processing of suspensions
   'check' => 1,	# whether to check system for bad users
);

# main code - no need to edit below here
use strict;
use Fcntl qw(:DEFAULT :flock);
use Net::LDAP;
use User::pwent;
use Sys::Syslog;

# die unless we're root (real uid)
die "Permission Denied" unless $< == 0;

# create syslog connection
openlog($0,undef,'authpriv');

&get_args(\@ARGV);
if ($conf{DEBUG}) {
   print STDERR "Conf keys:\n";
   foreach my $key (keys %conf) {
      print STDERR "K: $key V: $conf{$key}\n";
   }
}

#read suspend file and store in hash reference
my $suspend = &hash_suspend;

$| = 1 if $conf{verbose};

if ($conf{'suspend'}) {
  if (-f $conf{'suspend-file'} ) {
      if ($conf{verbose}) {
         print "Scanning $conf{'suspend-file'} for accounts.\n";
      }
      foreach my $account (keys %$suspend) {
         &suspend($account);
      }
      # clear suspend file
      sysopen(SUSPEND, $conf{'suspend-file'}, O_WRONLY | O_TRUNC | O_CREAT) or &complain("Couldn't write $conf{'suspend-file'}: $!",1);
      flock(SUSPEND, LOCK_EX) or &complain("Couldn't get exclusive lock on $conf{'suspend-file'}: $!",1);
      print SUSPEND "";
      close SUSPEND;
  } else {
      &complain("$conf{'suspend-file'} not regular. Entering immediate suspend mode");
      $conf{'suspend-now'} = 1;
      $conf{'check'} = 1;
  }
}
if ($conf{check} && (! $conf{suspend} || $conf{'suspend-now'}) ) {
   print "DEBUG: running suspend loop domain check\n" if $conf{DEBUG};
   while (my $spw = getpwent()) {
      next unless $spw->uid >= 500;
      next unless $spw->uid < 65534;
      unless (&check_LDAP_user($spw->name)) {
         # user doesn't exist in corporate domain
         &complain("user $spw->name not found in corp domain. Gecos: $spw->gecos");
         if ($conf{'suspend-now'}) {
            &suspend($spw->name);
         } else {
            &append_suspend($spw->name);
         }
      }
   }
}

# subroutines
sub check_LDAP_user {
   my $user = shift;
   my $return = undef;
   my $ldap = Net::LDAP->new('192.168.14.15') or die "$@ $!";
   my $DN = 'ldapquery@corp.interland.net';
   $ldap->bind(dn=>$DN, password => 'L00k1tUp');
   my $res = $ldap->search(
      base => 'dc=corp,dc=interland,dc=net', filter => "(sAMAccountName=$user)"
   );
   $res->code && &complain($res->error);
   my $numres = scalar $res->all_entries;
   $return = $numres > 0 ? 1 : undef;
   return $return;
}

sub get_args {          
   my $args = shift;    
   while (my $arg = shift @$args) {
       # assign - or -- strings into conf hash
       if ( my ($key,$value) = $arg =~ /^-{1,2}(\S+)=*(\S*)$/) {
          my @mult;
          if ($value =~ /.+,.+/) {
             @mult = split(/,/,$value);
             $conf{$key} = [@mult];
          } else {
	     unless (defined $value or $value != 0) { $value = 1; }
             $conf{$key}=$value;
          }
       } else {
          &help("Unknown argument: $arg");
       }
   }
   &help unless $conf{'suspend-file'} =~ m/^[\w\/]+$/;
   &help if $conf{h} or $conf{help};
}


sub complain {
   # code syslog interface here
   my $msg = shift;
   my $die = shift;
   syslog('info',$msg);
   if ($die) { 
      closelog();
      exit 1;
   }
}


sub help {
   my $message = shift;
   print STDERR <<HELP;
$message
Usage: $0 -[-]option[=value]
Options:
--verbose[=0]		Turn on (of off) script output
--suspend		This mode suspends previously detected bad users
			Without this option, script will just output bad users
			to "suspend file"
--suspend-file=filename File to which bad accounts are written, which can be
			processed later for suspension
--suspend-now		This mode suspends bad users detected in this run
HELP
   exit 1;
}

sub suspend {
    my $account = shift;
    # do some checking to make sure we don't disable key system accounts
    next unless $account =~ /^\w$/;
    my $spw = getpwnam($account);
    next unless $spw->uid >= 500;
    next unless $spw->uid < 65534;
    my @com = ("/usr/sbin/usermod","-s","/sbin/nologin","-L",$account);
    system(@com) == 0 && &complain("system @com failed: $?",1);
    if ($conf{verbose}) { 
       print "Suspended account: $account\n";
    }
}

sub hash_suspend {
   my $return = {};
   if (-f $conf{'suspend-file'}) {
      open SUSPEND, "<$conf{'suspend-file'}" or &complain("Couldn't read $conf{'suspend-file'}: $!",1);
      flock(SUSPEND, LOCK_SH) or &complain("Couldn't obtain shared lock on $conf{'suspend-file'}: $!",1);
      while (<SUSPEND>) {
         chomp;
         next if /^\s*#/;
         $return->{$_} = 1;
      }
      close SUSPEND;
   }
   return $return;
}

sub append_suspend {
    my $user = shift;
    sysopen (SUSPEND, $conf{'suspend-file'}, O_WRONLY | O_APPEND | O_CREAT) or &complain("Error appending to $conf{'suspend-file'}: $!",1);
    flock(SUSPEND, LOCK_EX) or &complain("Error obtaining exclusive lock on $conf{'suspend-file'}: $!",1);
    print SUSPEND "$user\n";
    close SUSPEND;
    if ($conf{verbose}) { print "Added $user to $conf{'suspend-file'}\n"; }
}
