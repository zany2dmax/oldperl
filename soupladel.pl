#!/usr/bin/perl

# script to be run from scooby that will "dish" user passwords to
# soupnazifor distribution

# steps
# 1. determine if scooby password file changed recently, otherwise exit quietly
# 2. determine which users should be distributed via soupnazi
# 3. create a BSD password file of the given users
# 4. copy password file to soupnazi
# 5. soupnazi will generate and distribute FATSI spwd.db file to Freedom boxes for FATSI access
# Note: even though scooby may allow a user to be in multiple FATSI groups,
#       soupnazi only distributes the user group stored in the password file
#       so only the main user's group will be recognized. This script will
#       only distribute the information for the highest GID of any FATSI
#       groups the user may be enrolled in.
#       
# To Do: 
# - cause a user account to be removed from FATSI password file if
#   the password is expired in the scooby /etc/shadow file

use strict;
# must only run as root
die "NO SOUP FOR YOU!!! Access Denied.\n" unless $< == 0;

# default settings
my %default = (
	# list of groups that indicate fatsi access
	# key=scooby gid, value = soupnazi/fatsi gid
	gid => {414=>200,415=>300,416=>400,417=>500,418=>600,419=>700,420=>99}, 
	tmpdir => "/tmp",
	remoteuser => 'scoobyfatsi',
	remotehost => 'soupnazi.lightrealm.com',
	remotefile => 'fatsi.passwd',
	timecheck => 120, # age (in seconds) of /etc/shadow or /etc/group
							# which determines if changes are needed
	maxtime => 43200, # maximum age of /etc/shadow or /etc/group, older
							# than this will automatically run script
	DEBUG => 0,
);

# no configuration done after this point

# main code
&scrutinize;
&dishout(&lineup(&biased));

# subroutines

# exit nicely if specific system files haven't been modified or
# we haven't exceeded default maxtime value
sub scrutinize { 
   my $now = time;
	my $ex = 0;
	foreach my $file ("/etc/shadow","/etc/group") {
	   my $modified = (stat($file))[9];
		if ($now - $modified >= $default{timecheck}) {
	   	unless ($now - $modified >= $default{maxtime}) {
				$ex = 1;
			}
		} else { $ex = 0; }
	}
	exit 0 if $ex;
}

# determine which users should be distributed via soupnazi
sub biased {
	my $users = {};

	# find members in the default groups
	foreach my $gr (keys %{$default{gid}}) {
		my @grinfo = getgrgid($gr);
		foreach my $useringroup (split(/\s/,$grinfo[3])) {
			if (exists $users->{$useringroup}->{group}) {
			   if ($gr > $users->{$useringroup}->{group}) {
					$users->{$useringroup}->{group} = $gr;
				}
			} else {
				$users->{$useringroup}->{group} = $gr;
			}
		}
	}

   while (my @uent = getpwent) { 
		# iterate through password file for all users, just in case
		# someone's main user group is one of the system groups (unusual)
		# @uent = (name,passwd,uid,gid,quota,comment,gcos,dir,shell)
		if (defined $default{gid}{$uent[3]}) {
      	if (defined $users->{$uent[0]}->{group}) {
			   if ($uent[3] > $users->{$uent[0]}) {
				    $users->{$uent[0]}->{group} = $uent[3];
				}
			}
		}
		if (defined $users->{$uent[0]}) {
		   $users->{$uent[0]}->{info} = \@uent;
		}
	}
	return $users;
}

# create BSD style password file
sub lineup {
	my $users = shift;
	my $tmpfile = $default{tmpdir} . "/fatsi." . $$ . "." . int(rand(10000));
	open PATRONS, ">$tmpfile" or die "NO SOUP FOR YOU! Couldn't write to $tmpfile: $!\n";
	# format of password entry:
	# user:md5pass:uid:gid::0:0:GEKOS:/home/directory:/shell
	foreach my $user (sort {$users->{$a}->{info}->[2] <=> $users->{$b}->{info}->[2]} keys %$users) {
	   print "writing user $user\n" if $default{DEBUG} > 1;
		printf PATRONS ("%s\:%s\:%d\:%d\:\:0\:0\:%s\:%s\:%s\n",
			$user,
			$users->{$user}->{info}->[1],
			$users->{$user}->{info}->[2],
			$default{gid}{$users->{$user}->{group}},
			$users->{$user}->{info}->[6],
			$users->{$user}->{info}->[7],
			'/sbin/nologin'
		);
	}
	close PATRONS;
	return $tmpfile;
}

# copy password file to remote system
sub dishout {
	my $file = shift;
	my $remote = $default{remoteuser} . '@' . $default{remotehost} . ':' . $default{remotefile};
	if( system("/usr/bin/scp",$file,$remote) == 0) {
	   unlink ($file);
	} else {
	   my $scpres = $?;
		unlink ($file);
		die sprintf ("NO SOUP FOR YOU!!! scp resulted in exit value %d signal %d\n", $scpres >> 8, $scpres & 127);
	}
}
