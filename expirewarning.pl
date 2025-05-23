#!/usr/bin/perl

# script designed to be run via cron to warn users that their password 
# is about to expire

# configuration - you can modify the defaults here, or use command-line
# flags to change these on the fly
my %conf = (
   verbose => 0,	# set to 0 by default (cron)
   uidmin => 500,	# minimum uid to scan
   uidmax => 65534,	# max uid to scan
   wdays => 7,		# If user has x days left on password, will warn
   debug => 0,		# debug mode
);

# main - no need to edit below here
use strict;
use Linux::usermod;
use User::pwent;
$|=1;

# run only as root (real)
die "Permission denied. Real uid $< != 0\n" unless $< == 0;

# iterate through password user list and find 
while (my $pw = getpwent) {
   next unless $pw->uid >= $conf{uidmin};
   next unless $pw->uid <= $conf{uidmax};
   my $shadow = Linux::usermod->new($pw->name);
   # find out how many days since last change
   my ($last,$exp,$dis) = ($shadow->show('dsalch'),$shadow->show('must'),$shadow->show('expire'));
   my $nowday = int(time() / 86400);
   my $c = $nowday - $last;
   my $diff = $exp - $c;
   my $data = {'last'=>$last,'expire'=>$exp,'disable'=>$dis,'diff'=>$diff};
   my $info = $pw->gecos;
   my ($email) = $info =~ /<(\S+\|\S+)>/;
   $email =~ tr/|/@/;
   if ($diff <= $conf{wdays}) {
      &warnmail($pw->name,$email,$data) or warn "Error mailing report for $pw->user: $!\n";
   }
}

# subroutines
sub warnmail {
   my $user = shift;
   my $addr = shift;
   my $data = shift;
   unless ($addr) { warn "no address supplied for user $user\n"; return 0; }
   my $absdiff = $data->{diff} < 0 ? $data->{diff} - ($data->{diff} * 2)  : $data->{diff};
   my $notice = $data->{diff} <= 0 ? "notice" : "warning";
   my $subject = "Password expiration $notice for $user on scooby.interland.net";
   my $expiremsg = $data->{diff} <= 0 ? "has been expired for at least $absdiff days." : "will expire in $absdiff days.";
   my $actionmsg = $data->{diff} <= 0 ? 
"Please contact the Security Operations Center for assistance on 
re-activating your account." :
"Please login to scooby.interland.net and use the passwd command to change your
local system password before it expires. Failure to reset your password will 
result in the disabling of your account on this machine.";
   my $message = <<MES;
From: Scooby Doo <root\@scooby.interland.net>
Reply-to: splitter\@velma.interland.net
To: $addr
Subject: $subject

This is an automated system notice to inform you that the local account password
for user $user on scooby.interland.net $expiremsg
This account is used to gain access to production systems. A disabled password
means that you will not be able to access this system, regardless of the state
of your safeword token or account.

$actionmsg

Please do not reply directly to this message, as it is not likely to be read
by a human. If you have questions regarding this message, contact your manager
or the Security Operations Center.
MES
   if ($conf{debug}) {
      print "User: $user\n$message";
   } else {
      open MAIL, "|/usr/sbin/sendmail -f root\@scooby.interland.net $addr" or return undef;
      print MAIL $message;
      close MAIL;
   }
   return 1;
}
sub get_args {
   my $args = shift;
   while (my $arg = shift @$args) {
       # assign - or -- strings into conf hash
       if ( my ($key,$value) = $arg =~ /^-{1,2}(\w+)=*([\w,%]*)$/) {
          unless (defined $value || $value == 0) { $value = 1; }
	  my @mult;
          if ($value =~ /.+,.+/) {
             @mult = split(/,/,$value);
             $conf{$key} = [@mult];
          } else {
             $conf{$key}=$value;
          }
       } else {
          &help("Unknown argument: $arg");
       }
   }
   &help if $conf{h} or $conf{help};
}

sub help {
   my $string = shift;
   print "$string\n" if $string;
   print <<HELP;
Usage: $0 -[-]option[=value[,value]] [...]
Options:
--verbose		Turns on verbosity. Since script is designed to be
			run via cron, this option is off by default.
--wdays=x		If user has x days left on their password, script will
			mail warning to user. Default value is 7 days.
HELP
}
