#!/usr/bin/perl 

# doall script for managing server platforms like tennessee

# configuration settings - these can all be changed by setting command-line
# argument options 
my %conf = (
   invdb => 'inventory',
   invdbhost => 'velma.interland.net',
   invdbuser => 'tenninventory',
   invdbtable => 'tennessee',
   invdbpass => 'ruhroh!',
   lastupdate => 0, # Number of days since last inventory update that will
   		    # be matched for server inventory. At 0, this means that 
		    # only servers which have "checked in" within the past 24
		    # hours will be listed in server list for this command
   verbose => 1,    # by default, script is verbose.
   con => 'private',
   port => 22,	    # default ssh port
   user => 'root',  # default remote ssh user
   color => 'dark', # ansi color for dark terminal
);

# main - no need to edit below here
$|=1;
use strict;
use DBI;
my $command = &get_args(\@ARGV);
if ($conf{color}) { use Term::ANSIColor; }

my $list = &serverlist;
if ($conf{list}) { 
   if (defined $conf{include}) {
      if ($conf{color}) { print color 'bold'; }
      printf "Include regex applied: %s\n", join ",",@{$conf{include}} if $conf{verbose};
      if ($conf{color}) { print color 'reset'; }
   } 
   if (defined $conf{exclude}) {
      if ($conf{color}) { print color 'bold'; }
      printf "Exclude regex applied: %s\n", join ",",@{$conf{exclude}} if $conf{verbose};
      if ($conf{color}) { print color 'reset'; }
   }
 if ($conf{list} eq 'full') {
 if (! exists $conf{nowarn} || ! $conf{verbose} ) {
   if ($conf{color}) { print color 'bold red'; }
   print "\nWarning!! Hostnames are obtained from remote hosts, and do not\n",
   "necessarily correlate to a valid IP address via DNS. For best results\n",
   "use private IP addresses for administrative connections from this host.\n\n";
   if ($conf{color}) {
      print color 'reset';
   }
 }
   printf "%-20s %-15s %-15s %-8s\n", "Hostname", "Public","Private","Checkin";
   foreach my $entry ( keys %{$list->{hostname}} ) {
       my $data = $list->{hostname}->{$entry};
       #printf "D: data=%d (%s) ref=%s d=%s\n", scalar @$data, $entry, ref $data , join (",",@$data);
       printf STDOUT ("%-20s %-15s %-15s %-8d\n",$entry , $data->[1],$data->[2],$data->[6]);
   }
 } else {
   if ($conf{color}) { print color 'bold red'; }
   if ($conf{list} eq 'hostname' && ($conf{verbose} != 0 || ! exists $conf{nowarn})) { 
      print "\nWARNING!! Hostnames are obtained from remote hosts, and do not\n",
      "necessarily correlate to a valid IP address via DNS. For best results\n",
      "use private IP addresses for administrative connections from this host.\n\n",
      "This list excludes hosts without a valid private IP address (on eth1)\n",
      "For other listing options, run doall --help\n\n";
   }
   if ($conf{color}) {
      print color 'reset';
   }
   foreach my $entry ( keys %{$list->{$conf{list}}} ) {
     if ($conf{list} eq 'hostname') {
       print $entry . "\n" if $list->{hostname}{$entry}[2];
     } else {
       print $entry . "\n" ;
     }
   }
 }
} else {
   foreach my $entry ( sort keys %{$list->{$conf{con}}} ) {
       if ($conf{color}) {
         if ($conf{color} eq 'light') {
            print color 'bold blue';
          } elsif($conf{color}) {
            print color 'bold yellow';
         }
       }
       my @com = @$command;
       if ($conf{verbose}) {
           printf STDOUT "%s %s: %s\n", $entry, $conf{con} eq 'hostname' ? "" : "(" . $list->{$conf{con}}->{$entry}->[0] . ") ", join(" ", @$command);
       }
       if ($conf{color}) { print color 'reset'; }
       unshift @com, "$conf{user}\@$entry" ; 
       if ($conf{key}) {
          unshift @com, ("-i",$conf{key});
       }
       unshift @com, ("-p", $conf{port});  

       # following must be first in command arguments
       unshift @com, ("/usr/bin/ssh");
       if ($conf{verbose}) {
         my $cmd = join " ", @com;
	 print qx/$cmd/;
       } else {
         system(@com) == 0 or printf STDERR "Error. Returned code%d\n", $? >> 8 ;
       }
   }
}

# subroutines

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

sub get_args {
   my $args = shift;
   my @command;
   while (my $arg = shift @$args) {
       # if argument is single -, don't interpret any more args but
       # assume that the rest is the command to be run
       if ($arg =~ /^-$/) {
          while (my $rest = shift @$args) {
	     push @command, $rest;
	  }
	  last;
       }
       # assign - or -- strings into conf hash
       if ( my ($key,$value) = $arg =~ /^-{1,2}(\w+)=*([\w,%]*)$/) {
	  #$value ||= 1;
	  unless ($value == 0 || defined $value) { $value = 1; }
          #print "\$conf{$key}=$value\n"; 
	  if ($key eq 'include' or $key eq 'exclude') {
	     my @mult = split(/,/,$value);
	     $conf{$key} = [@mult];
	  } else {
	     $conf{$key}=$value;
	  }
       } else {
       # arguments not starting with - are assumed to be commands
          #print "arg $arg doesn't match regex\n"; 
	  push @command, split(/\s/, $arg);
       }
   }
   &help if $conf{h} or $conf{help}; 
   &help unless scalar @command or $conf{list};
   if ($conf{list} eq 1) { $conf{list} = 'full' ;}
   if ($conf{con} eq 1) { $conf{con} = 'private' ;}
   &easter if exists $conf{easter};
   return \@command;
}

sub help {
   print <<HELP;
Usage: $0 -[-]option[=value] [-] command
Options:
-		Ignore all subsequent options, intepret as doall command
--user=username	Specifies remote user (default root)
--key=file	Specifies the private key used for connection
--verbose[=0]   Turns off verbosity (which is on by default)
--list[=value]  Lists hostnames without running a command. You can list 
                hostname, public or private IP addresses if you specify
		"hostname", "public" or "private" as the argument value.
		Using "full" as the argument value will generate hostname,
		public, and private, which is the default action.
--con=value	Specifies method which is used to connect to remote systems
		Default value for this is private, but may be specified to
		connect via public,private,hostname methods.
--port=value	Specifies the connection port to use for ssh commands.
		Default port is 22
--nowarn	Do not print warning messages 
--color=[dark|light|0]
		By default, ansi color will be used to distinguish server
		names from the command output. Default value is for dark
		Terminal.
--lastupdate=x  By default, doall will only list or execute commands against
		servers who have "checked in" to the syslog database within
		the past 24 hours. This limitataion can be extended by x days
		using this argument
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
HELP
   exit 1 unless $conf{easter};
}

sub easter {
   my $egg = "/opt/scooby";
   open EGG, $egg or die "Sorry, no scooby snack, no easter egg!\n";
   while (<EGG>) { print; }
   close EGG;
   exit 0;
}
