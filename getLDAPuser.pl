#!/usr/bin/perl

unless ($ARGV[0]) { die "Usage: $0 [-v] username\n"; }
if($ARGV[0] =~ /^-v/) {
	$VERBOSE = 1;
	$user = $ARGV[1];
} elsif ($ARGV[0] =~ /^-n/) {
   $name = $ARGV[1];
} else {
	$user = $ARGV[0];
}

use Net::LDAP; 
$ldap = Net::LDAP->new('192.168.14.15') or die "$@ $!"; 
my $DN = 'ldapquery@corp.interland.net';
$ldap->bind(dn=>$DN, password => "L00k1tUp"); 
if ($name) {
   print "Searching for name $name\n";
   $mesg = $ldap->search(
   base =>'dc=corp,dc=interland,dc=net', filter => "(displayName=$name)"
	);
} else {
   print "Searching for user $user\n";
   $mesg = $ldap->search(
   base =>'dc=corp,dc=interland,dc=net', filter => "(cn=$user)"
	);
}
$mesg->code && die $mesg->error; 
if (my $num = scalar $mesg->all_entries) {
   print $num == 1 ? "$num entry found\n" : "$num entries found\n";
}
foreach $entry ($mesg->all_entries) { 
	if($VERBOSE == 1) {
		$entry->dump;
	} else {
		print $entry->get_value('cn') . " - " . $entry->get_value('mail') . " = " . $entry->get_value('displayName') . "\n";
	}
} 
$ldap->unbind;
