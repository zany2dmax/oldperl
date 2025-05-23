#!/usr/bin/perl 

use strict;
use warnings;

my @cmdName = (
	'addTargetServer' => ( hostName => "binford", ipAddress => "10.50.81.170"),
	'addTargetApplication' => ( targetServerHostName => "undercurrent", 
								targetApplicationType => "Generic",
								targetApplicationName => "" )
);
my $COUNT = scalar (@cmdName);
my $HASH1CT = scalar(keys(%cmdName[0]{));
for (my $i=0; $i<$COUNT; $i++) {
	print '$cmdName[' . $i .'] is: ' . $cmdName[$i] . "\n";
}
