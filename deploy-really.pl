#! /usr/bin/perl -w

use strict;

if(!defined($ARGV[0])) {
	die("usage: deploy-really.pl FILENAME OSTYPE");
}

if(!defined($ARGV[1])) {
	die("Usage: deploy-really.pl FILENAME win2k|winnt");
}

open(FILE, $ARGV[0]) or die("$0: $1: $@");

while(<FILE>) {
	chomp;
	my $ip = $_;
	my $base = "\\\\$ip\\c\$";
	print STDERR "*** Processing $ip\n";

	print STDERR "    Creating directories.\n";
	mkdir("$base\\ibin") or warn("Can't create IBIN: $!");
	mkdir("$base\\ibin\\patchlink") or warn("Can't create PATCHLINK: $!");

	print STDERR "    Copying files.\n";
	if($ARGV[1] eq "win2k") {
		system("copy /y install_2k.bat $base\\ibin\\patchlink\\install.bat");
		system("copy /y patchlinkwin2k.reg $base\\ibin\\patchlink");
	}

	elsif($ARGV[1] eq "winnt") {
		system("copy /y install_nt.bat $base\\ibin\\patchlink\\install.bat");
		system("copy /y patchlinkwinnt.reg $base\\ibin\\patchlink");
	}

	system("copy /y updateagent.msi $base\\ibin\\patchlink");
	system("copy /y reg.exe $base\\ibin\\patchlink");
	system("copy /y sleep.exe $base\\ibin\\patchlink");

	print STDERR "    Creating scheduled task.\n";
	system("soon \\\\$ip 180 /interactive c:\\ibin\\patchlink\\install.bat");

	print STDERR "    Done.\n";
}

print STDERR "Finished processing servers in input file.\n";

exit(0);
