#!/usr/bin/perl

# script to distribute new passwords to production systems
# It is assumed that this will be connecting directly to remote systems as root (via keys)
# For obvious reasons, access to run this command should be limited
# this interactively ask for a password and distribute the a randomly salted crypted string
# based on the main password to each system for updated in the /etc/shadow file

# default configuration
my %conf = (
   'platform' => 'tennessee',
   'invdb' => 'inventory',
   'invdbhost' => 'velma.interland.net',
   'invdbuser' => 'tenninventory',
   'invdbpass' => 'ruhroh!',
   'lastupdate' => 0,
   'verbose' => 1,
   'if' => 'private',
   'port' => 22,
   'user' => 'root',
   'key' => '/root/.ssh/id_dsa',
   'DEBUG' => 0,
);

####################################
# main - no need to edit below here
####################################
use strict;
use DBI;
use Digest::MD5 qw(md5 md5_hex md5_base64);
$|=1;

&get_args(\@ARGV);
unless (exists $conf{invdbtable}) { 
  $conf{invdbtable} = $conf{platform}; 
}
my $pasnoun = $conf{mysql} ? "mysql password" : "password"; 
print STDOUT "Changing $pasnoun for user $conf{user} on platform $conf{platform}\n";
my $list = &serverlist;
if ($conf{mysql}) {
   $conf{mysqloldpass} = &getpass("current mysql"); 
}
my $pass = &getpass;
foreach my $ip (keys %{$list->{$conf{if}}}) {
   if ($conf{mysql}) {
      my @command = (
         "/usr/bin/ssh","-i",$conf{key},"-l","root",$ip,
	 "/usr/bin/perl","-e",
	 "/usr/bin/mysql","--user=$conf{user}","--password='$conf{mysqloldpass}'",
	 "-e","'set password for root=password(\"$pass\")'",
	 "||","/bin/false",
      );
     
      system @command ? print "finished on $ip\n" : printf STDERR "Warning: failure on $ip with value %d\n", $? >> 8 ;
      print
   } else {
      # generate password hash
      # random salt
      my $salt = '$1$' . md5_hex(&randchar(38)); 
      my $crypted = crypt($pass,$salt);
      my @command = ("/usr/bin/ssh","-i",$conf{key},"-l","root",$ip,"/usr/sbin/usermod","-p","'$crypted'",$conf{user});
      printf "$ip: $crypted\n";
      system @command and printf STDERR "Warning: failure on $ip with value %d\n", $? >> 8;
   }
}

##################
# subroutines
##################

sub get_args {
   my $args = shift;
   while (my $arg = shift @$args) {
       # assign - or -- strings into conf hash
       if ( my ($key,$value) = $arg =~ /^-{1,2}(\w+)=*([\w,%]*)$/) {
          $value ||= 1;
          #print "\$conf{$key}=$value\n"; 
          if ($key eq 'include' or $key eq 'exclude') {
             my @mult = split(/,/,$value);
             $conf{$key} = [@mult];
          } else {
             $conf{$key}=$value;
          }
       } 
   }
   &help if $conf{h} or $conf{help}; 
}

sub help {
   print <<HELP;
Usage: $0 -[-]option[=value]
Options:
--platform=name	Specify the platform name, defaults to tennessee
--include=regex[,regex]
                This will allow you to include only the hostnames which match
                the mysql-style regex. For example, if you want to include all
                hostnames that are in the mysql class for tennessee, you could
                run --include=\%sqlg\%. You can specify multiple regexes
                separated by commas.
--exclude=regex[,regex]
                This will allow you to exclude only the hostnames which match
                the mysql-style regex. For example, if you want to exclude all
                hostnames that are in the mysql class for tennessee, you could
                run --exlude=\%sqlg\%. You can specify multiple regexes
                separated by commas.
--user=username Specifies remote user (default root)
--key=file      Specifies the private key used for connection
--verbose[=0]   Turns off verbosity (which is on by default)
--port=value	Specifies the connection port to use for ssh commands.
		Default port is 22
--if={public|private}
		Specifies whether to connect via the public or private network
		interface. Default is private.
--lastupdate=x  By default, this will only perform password modifications to
                servers who have "checked in" to the syslog database within
		the past 24 hours. This limitataion can be extended by x days
		using this argument
--mysql		Updates mysql password rather than login password

HELP
   exit 1;
}

sub serverlist {
   my %public = (); my %private = (); my %host = (); my $and = undef; my $logic = 'and';
   if (defined $conf{exclude}) {
      foreach my $reg (@{$conf{exclude}}) {
         $and .= " and hostname not like '$reg'";
      }
   }
   if (defined $conf{include}) {
      foreach my $reg (@{$conf{include}}) {
         $and .= " $logic hostname like '$reg'";
         $logic = 'or';
      }
   }
   my $dbh = DBI->connect("DBI:mysql:database=$conf{invdb}:host=$conf{invdbhost};", $conf{invdbuser}, $conf{invdbpass});
   die "Fatal: $DBI::errstr\n" if $DBI::errstr;
   my $query = "select hostname, inet_ntoa(public),inet_ntoa(private),pubmac,privmac,updated, to_days(current_date) - to_days(updated) as lastupdate from $conf{invdbtable} where to_days(current_date) - to_days(updated) <= $conf{lastupdate} $and";
   my $sth = $dbh->prepare($query);
   if ($conf{DEBUG}) { printf "Query:\n%s\n", $query; }
   $sth->execute;
   if ($DBI::errstr) { die "Fatal: $DBI::errstr\n"; }
   while (my $raddr = $sth->fetchrow_arrayref) {
      # hash hosts
      $host{$raddr->[0]} = [@$raddr];
      # hash ips
      #printf STDERR ("0: %s 1: %s 2: %s\n",$raddr->[0],$raddr->[1], $raddr->[2]);
      $public{$raddr->[1]} = [@$raddr] if $raddr->[1];
      $private{$raddr->[2]} = [@$raddr] if $raddr->[2];
   }
   $dbh->disconnect;
   # slice and dice any way you like
   return {'hostname'=>\%host,'public'=>\%public,'private'=>\%private};
}

sub getpass {
   my $adj = shift;
   $adj ||= "new";
   my ($word,$check) = (undef,undef);
   print STDOUT "Enter $adj password: ";
   system ("stty","-echo");
   chomp ($word = <STDIN>);
   print "\n";
   system ("stty","echo");
   print STDOUT "Again: ";
   system ("stty","-echo");
   chomp ($check = <STDIN>);
   print "\n";
   system ("stty","echo");
   die "Passwords do not match!\n" unless $word eq $check;
   return $word;
}

sub randchar {
 my $length = shift;
 $length ||= 10;
 my @chars = ();
 my $password;
 my $rand;
 foreach ('a'..'z','A'..'Z',0..9) { push @chars, $_; }
 push @chars, split(",","-,_,%,#");
 srand;
 for (my $i=0; $i < $length; $i++) {
    $rand = int(rand $#chars);
    $password .= $chars[$rand];
 }
 return $password;
}

