#!/usr/bin/perl -w

use strict;
use CGI qw(:standard);
use LWP::Simple;
use Net::FTP;

my $SNMPWALK = '/opt/local/snmp/bin/snmpwalk';
my $e = new CGI;
my $ip = $e->param('ip');
my $community = $e->param('community');
my $oid = $e->param('oid');
if (!$community) { $community = "interlandsnmp"; }

if (!$oid) { 
				$oid = '.1.3.6.1.2.1.1.5.0'; 
			}
print $e->header();
if (!$ip) { 
	print &form;	
} else { 
	print &form;
	print "<BR><HR ALIGN=center><BR>\n";
	&snmpwalk($ip,$community,$oid);
	&HTTPSERVERUP($ip);
	print "<BR>";
	&FTPSERVERUP($ip);
}


sub snmpwalk { 
	my $ip = shift;
	my $community = shift;
	my $oid = shift;
	my @split = ();
	my @out = `$SNMPWALK -v2c -c$community $ip $oid`;
	if (@out) { 
		foreach (@out) { 
			if ($_ =~ /=/) { 
				@split = split(/=/, $_);
				print $e->b($split[0]) . " = " . $split[1] . $e->br . "\n";
			}
		}
	} else { 
		print "No response from $ip with $community\n";
	}
}

##  VERY Simple HTTP Test - added 1/10/05 by Jeff Leggett
sub HTTPSERVERUP {
	my $IP = shift;
	$IP = 'http://' . $IP;
	if (defined (my $CONTENT = get ($IP))) {
		print "HTTP Server is up\n";
	} else { print "HTTP Server has a problem\n"; }
}

## VERY Simple FTP Test - added 1/10/05 by Jeff Leggett
sub FTPSERVERUP {
    my $IP = shift;
    if (defined (my $FTP = Net::FTP->new($IP))) {
        print "FTP Server accepted a connection\n";
    } else { print "FTP Has a problem: $@\n"; }
}

sub form { 
	my @ret;	
	push @ret, $e->start_form({-action=>$ENV{REQUEST_URI},-method=>"post"});
	push @ret, $e->start_table({-border=>0,-cellpadding=>5});
	push @ret, $e->Tr($e->td("IP Address"),$e->td($e->input({-type=>"text",-name=>"ip",-value=>$ip})),$e->td($e->input({-type=>"submit",-value=>"Walk It!"})));
	push @ret, $e->Tr($e->td("Community String"),$e->td({-colspan=>2},$e->input({-type=>"text",-name=>"community",-value=>$community})));
	push @ret, $e->Tr($e->td("OID"),$e->td($e->input({-colspan=>2,-type=>"text",-name=>"oid",-value=>$oid})));
	push @ret, $e->end_table;
	push @ret, $e->end_form;
	
	return @ret;
}

