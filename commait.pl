#!/usr/bin/perl -w

while (<>) {
	chomp $_;
	if ($_ =~ /^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)/) {
		($IPADDR,$HI,$LOW,$INFO) = split /\s+/, $_, 4;
		print "$IPADDR,$HI,$LOW,$INFO\n";
	}
	else { print "$_\n"; }
}

