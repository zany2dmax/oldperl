#!/usr/bin/perl

# autoreboot.pl - written by D. Kampenhout
# created 8/16/04
# script designed to be run via cron, will initiate a shutdown
# command if the system uptime is more than the specified number of days
# BTW, this document looks best if tab size = 3 (vi: set ts=3)
use strict;

# configuration
my %default = (
	uptime_trigger => 8,	# If system uptime is less than x days, script will exit
	shutdown_cmd => ['/sbin/shutdown','-r'],
   verbose => 1,			# set to 0 to turn off any output
	message => "System will be rebooted for routine maintenance. User sessions will be terminated; You may reconnect your session after the system recovers from the reboot process.",
	timestring => '01:50',# this is the time string passed to shutdown command
	DEBUG => 0,				# if set to 1, debug mode will just print results and
								# not actually reboot the system
);

# main code - do not edit below here
$|=1;
use strict;
my $pid = undef;
# we'll only run as root
die "Permission Denied!!!\n" unless $< == 0;
&checkuptime;
&initiate;
exit 0;


# subroutines
sub checkuptime {
   open UPTIME, "</proc/uptime" or die "could not determine system uptime!!\n";
	my $uptimeraw = <UPTIME>;
	close UPTIME;
	my ($uptimesec) = split /\s/,$uptimeraw;
	my $uptimedays = sprintf("%2.2f", (($uptimesec / 24)/60)/60);
   if ($uptimedays <= $default{uptime_trigger}) {
		if ($default{verbose}) {
			printf "System uptime %2.2f days is less than threshold of %2.2f, aborting.\n", $uptimedays, $default{uptime_trigger};
		}
		exit 0;
	}
	return 1;
}

sub initiate {
   my $cmd = $default{shutdown_cmd};
	push @$cmd, ($default{timestring},"'$default{message}'");
	my $vstring = sprintf("Initiating shutdown with command: %s\n", join (" ", @$cmd));
	if ($default{DEBUG}) {
	    print "DEBUG MODE, execution not enabled\n" . $vstring;
		 exit 0;
	} elsif ($default{verbose}) {
	    print $vstring;
	}
	if ( $pid = fork ) {
	   return 1;
	} elsif ( defined $pid ) {
	   # exec command in child process so parent can die without freezing
		exec @$cmd;
		return 1;
	} else {
	   die "Couldn't fork to exec. Failed\n";
	}
}
