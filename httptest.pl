#!/usr/bin/perl -w

use strict;
use LWP::Simple;
use Net::FTP;

my $IP = '66.132.193.8';
&HTTPSERVERUP($IP);
&FTPSERVERUP($IP);

sub HTTPSERVERUP {
	my $IP = shift;
        $IP = 'http://' . $IP;
        print "$IP\n";
	if (defined (my $CONTENT = get($IP))) {
		print "HTTP Server is up\n";
	} else { print "HTTP Server has a problem\n"; }
}

sub FTPSERVERUP {
	my $IP = shift;
	if (defined (my $FTP = Net::FTP->new($IP))) {
		print "FTP Server accepted a connection\n"; 
	} else { print "FTP Has a problem: $@\n"; }
}
	
