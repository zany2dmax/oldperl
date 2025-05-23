#!/usr/bin/perl

# script to create new scooby user
use strict;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use User::grent;
use Date::Calc qw(Add_Delta_Days);
$|=1;

die "Permission denied. Real uid $< != 0\n" unless $< == 0;

my $arg = &getargs(\@ARGV);
my $salt = md5_hex(&randpass(38));
$salt = '$1$' . $salt;
my $pass = &randpass;
my $crypted = crypt($pass,$salt);
my $exptime = &calcexpire($arg->{expire});
my $gemail = $arg->{email};
$gemail =~ tr/@/|/;

my @command = ("/usr/sbin/useradd","-m","-G","$arg->{group}","-d","/home/$arg->{username}","-p","$crypted","-s","/bin/bash","-f","3","-c","$arg->{fullname} $arg->{comgroup} <$gemail>","$arg->{username}");
printf("Running %s\n",join " ", @command);
my $return = system(@command);
die ("useradd failed: $!\n") if $return;
my @expirecmd = ("/usr/local/scripts/setexpire.pl","-u",$arg->{username},"-e",$arg->{expire},"-d",7);
my $return = system(@expirecmd);
die ("Password expiration setting failed with code $return\n") if $return;
printf("Setting quota to %d blocks\n", 100000);
my @quotacmd = ("/usr/sbin/setquota","-u",$arg->{username},100000,500000,0,0,"-a");
my $return = system(@quotacmd);
die ("Quota setting failed with code $return\n") if $return;
print "Sending plaintext password to $arg->{email}\n";
&emailpass($arg,$pass);
print "Finished.\n";


sub getargs {
   my $args = shift;
   my ($username,$group,$comgroup,$expire,$email,@groups) = ();
   while (my $arg = shift @$args) {
      if ($arg eq '-u') {
         $username = shift @$args;
	 unless ($username =~ /^\w+$/) {
	    warn "Invalid username '$username'!\n";
	    &help;
	 }
      } elsif ($arg eq '-e') {
         $email = shift @$args;
	 unless ($email =~ /^[\w.-]+\@[\w.-]+$/) {
	    warn "$email is not a valid email address\n";
	    &help;
	 }
      } elsif ($arg eq '-x') {
         $expire = shift @$args;
	 unless ($expire =~ /^\d+$/) {
	    warn ("$expire is not a valid expire days number\n");
	    &help;
	 }
    } elsif ($arg eq '-g') {
      $group = shift @$args;
	 	@groups = split ",", $group;
	 	foreach my $gr (@groups) {
	   	unless ($gr =~ /^\w+$/) {
	    		warn "$gr is not a valid group\n"; &help;
	   	}
	   	unless (my $gre = getgrnam($gr)) {
	   		warn "$gr is not a valid group\n"; &help;
	   	}
	 	}
   } elsif ($arg eq '-c') {
      $comgroup = shift @$args;
		unless ($comgroup =~ /^[\w ]+$/) {
	   warn "$comgroup is not a valid Company Group\n";
	   &help;
	}
      } else { 
         warn ("Arg $arg is not recognized.\n");
         &help;
      }
   }
   unless ($username) {
      print "Enter Username: ";
      chomp ($username = <STDIN>);
      die "invalid input!\n" unless $username;
   }
   my $det = get_LDAP_user($username);
   $username = $det->{uname};
   unless ($group) {
    GROUP: 
      print "Enter Group [support1]: ";
      chomp ($group = <STDIN>);
      $group ||= "support1";
      unless (my $gre = getgrnam($group)) {
	 warn "$group is not a valid group\n"; goto GROUP;
      }
   }
   unless ($comgroup) {
      print "Company Group [ATL Support]: ";
      chomp ($comgroup = <STDIN>);
      $comgroup ||= "ATL Support";
   }
   if (! defined $email and $det->{email} and $username ne 'test') {
      print "Using email $det->{email} as found from corp DC\n";
      $email = $det->{email};
   } 
   elsif (! defined $email) {
      print "Email Address [$username\@interland.com]: ";
      chomp($email = <STDIN>);
      $email ||= "$username\@interland.com";
   }
   unless ($expire) {
      print "How many days until password expires [21]: ";
      chomp ($expire = <STDIN>);
      $expire ||= 21;
   }
   return {'username'=>$username,'group'=>$group,'comgroup'=>$comgroup,'email'=>$email,'expire'=>$expire,'fullname'=>$det->{name}};
}

sub help {
  die <<HELP;
Usage: $0 [-u username] [-x #days] [-g group] [-c companygroup] [-e email]

Without any arguments, script will be interactive and will prompt for
appropriate values. Values are:
-u		username to be created
-x		# of days until password for this user expires
-g		system group that user will be part of
-c		Company group (i.e. Support, Ops, etc.)
-e		email address of user being added
HELP
}

sub randpass {
 my $length = shift;
 $length ||= 10;
 my @chars = ();
 my $password;
 my $rand;
 foreach ('a'..'z','A'..'Z',0..9) { push @chars, $_; }
 push @chars, split(",","-,_,%,#,|,!, ");
 srand;
 for (my $i=0; $i < $length; $i++) {
    $rand = int(rand $#chars);
    $password .= $chars[$rand];
 }
 return $password;
}

sub calcexpire {
  my $days = shift;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
  $year += 1900;
  $mon += 1;
  #print "D: Today $year $mon $mday $isdst\n";
  my ($newy,$newm,$newd) = Add_Delta_Days($year,$mon,$mday,$days);
  return "$newy-$newm-$newd";
}

sub emailpass {
   my ($val,$plain) = @_;
   my $date = scalar localtime();
   my $MSG = <<MSG;
From: Scooby Doo <root\@scooby.interland.net>
To: $val->{email}
Date: $date
Subject: Settings for $val->{username}

Hello $val->{fullname}.

This is an automatically generated message. 

An account has been created for you on scooby.interland.net. Please
log in and change the password for this account within $val->{expire}
days or the account will expire. 

*Please note*, this message is regarding your local password only. 
To access this box remotely, you will need to use the hardware token
and PIN that was or will be provided to you.

Username: $val->{username}
Password: $plain

For questions about how to use your new account, please ask your
manager or consult the company FAQ for your group.
MSG
   open MAILOUT, "|/usr/sbin/sendmail -f root $val->{email}" or die "Could not mail out to $val->{email}: $!\n";
   print MAILOUT $MSG;
   close MAILOUT;
   return 1;
}

sub get_LDAP_user {
   my $user = shift;
   use Net::LDAP; 
   my $return = undef;
   my $ldap = Net::LDAP->new('192.168.14.15') or die "$@ $!"; 
   my $DN = 'ldapquery@corp.interland.net';
   $ldap->bind(dn=>$DN, password => "L00k1tUp"); 
   my $mesg = $ldap->search(
   #base =>'dc=corp,dc=interland,dc=net', filter => "(cn=$user)"
   base =>'dc=corp,dc=interland,dc=net', filter => "(sAMAccountName=$user)"
           );
   $mesg->code && die $mesg->error; 
   my $nument = scalar $mesg->all_entries;
   if ( $nument > 1 ) {
      my $mess = "$user matched $nument entries. Please select which user is correct.";
      my %user = ();
      foreach my $entry ($mesg->all_entries) {
         #my $uname = lc $entry->get_value('cn');
         my $uname = lc $entry->get_value('sAMAccountName');
         my $email = lc $entry->get_value('mail');
         my $name = $entry->get_value('displayName');
	 $user{$uname} = {'email'=>$email,'name'=>$name};
      }
      my $selected = &selectuser(\%user,$mess); 
      $return = {'uname'=>$selected,'email'=>$user{'email'},'name'=>$user{'name'}};
   } elsif ( $nument) {
      my $entry = ($mesg->all_entries)[0];
      my $uname = lc $entry->get_value('sAMAccountName');
      my $email = lc $entry->get_value('mail');
      my $name = $entry->get_value('displayName');
      $return = {'uname'=>$uname,'email'=>$email,'name'=>$name};
      print "$user verified to exist in corporate domain: email=$email name=$name\n";
   } else {
      print "$user not found in corporate domain.\n";
      $return = &search_user;
   }
   $ldap->unbind;
   return $return;
}

sub selectuser {
   my ($users,$message)  = @_;
   print "$message\n";
  USER:
   print "Here are the possible users: ";
   foreach my $user ( keys %$users ) {
      print "$user \<$users->{'email'}\>\n";
   }
   print "Which user? :";
   my $chosen = chomp ( my $chosen = <STDIN>) ;
   unless ( exists $users->{$chosen} ) {
      warn "'$chosen' is not a valid user. Please choose again\n"; goto USER;
   }
   return $chosen;
}

sub search_user {
   my $return = undef;
   use Net::LDAP;
   my $ldap = Net::LDAP->new('192.168.14.15') or die "$@ $!";
   my $DN = 'ldapquery@corp.interland.net';
   $ldap->bind(dn=>$DN, password => "L00k1tUp");
   NAME:
   print "Enter Full Name: ";
   chomp (my $fullname = <STDIN>);
   my $mesg = $ldap->search(
   base =>'dc=corp,dc=interland,dc=net', filter => "(displayName=$fullname)"
           );
   my $num = scalar $mesg->all_entries;
   if ( $num > 1 ) {
      my $mess = "$fullname matched $num entries. Please select one.\n";
      my %user = ();
      foreach my $entry ($mesg->all_entries) {
         #my $uname = lc $entry->get_value('cn');
         my $uname = lc $entry->get_value('sAMAccountName');
         my $email = lc $entry->get_value('mail');
         my $name = $entry->get_value('displayName');
         $user{$uname} = {'email'=>$email,'name'=>$name};
      }
      my $selected = &selectuser(\%user,$mess);
      $return = {'uname'=>$selected,'email'=>$user{'email'},'name'=>$user{'name'}};
   } elsif ( $num == 1 ) {
      my $entry = ($mesg->all_entries)[0];
      #my $uname = lc $entry->get_value('cn');
      my $uname = lc $entry->get_value('sAMAccountName');
      my $email = lc $entry->get_value('mail');
      my $name = $entry->get_value('displayName');
      print "$fullname matched user id $uname\n";
      $return = {'uname'=>$uname,'email'=>$email,'name'=>$name};
   } else {
      warn "$fullname matched $num entries.\n"; goto NAME;
   }
   $ldap->unbind();
   return $return;
}
