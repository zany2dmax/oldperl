#!/usr/bin/perl

# ok, I was bored

my $quotefile = "/opt/scooby.quotes";
open QUOTE, $quotefile or die "Sorry. No scooby snack today\n";
my @quotes = <QUOTE>;
close QUOTE;
my $randnum = int(rand($#quotes));
printf STDOUT "Scooby-Doo Quote of the Session: %s\n", $quotes[$randnum];
