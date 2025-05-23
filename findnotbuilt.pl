#!/opt/etrade/p6/bin/perl -w
#
# findnotbuilt.pl - a script to compare your installed et_* RPM's with the 
#                   main source codebase of maven builds and figure out 
#                   what's left to build.
#                   Needs Number::Compare and File::Find::Rule installed 
#                   as a pre-req
# 
#                   Jeff Leggett, April 2008

use strict;
use warnings;
use File::Find::Rule;

sub getRPM_name {
  my $A = `rpm -q --queryformat '%{NAME}' $_`;
  return $A;
}
#
# Change this variable to point to your top level working directory
#
my $MAINTRUNK = "/etrade/home/jleggett/work/3p-stb";
my @EM, my @P6;
# 
# Find all installed ^et_ RPM's and get their name and branch
#
open PKGS, "rpm -q -g \"Maven 2.0\" |" or die "can't fork: $!";
while (<PKGS>) {
   my $PKG = $_;
   (my $A,my $B,my $C) = split /_/, $PKG, 3;
   chop($C);
   my $PKGNAME = getRPM_name($PKG); 
   (my $D,my $E,my $F) = split /_/, $PKGNAME, 3;
   if ($B eq "em") {
      push(@EM, $F); 
   }
   if ($B eq "p6") {  
      push(@P6, $F); 
   }
   next;
}
close PKGS;
# Search both branches - for directories with pom.xml in them.
my $RULE = File::Find::Rule->new;
$RULE->file;
$RULE->name( 'pom.xml' );
my @P6FILES = $RULE->in( "$MAINTRUNK/p6/" );
my @EMFILES = $RULE->in( "$MAINTRUNK/em/" );
# Remove any directories with a pom.xml in them in target subdiri
# and the pom.xml file itself from the main dir
foreach my $AREF (@P6FILES) {
   if ( $AREF =~ m/target/ ) { $AREF = "";  next; }
   $AREF =~ s/\/pom.xml//;
}
@P6FILES = sort(@P6FILES);
foreach my $AREF (@EMFILES) {
   if ( $AREF =~ m/target/ ) { $AREF = ""; next; }
   $AREF =~ s/\/pom.xml//;
}
@EMFILES = sort(@EMFILES);
foreach my $AREF (@P6FILES) {
   if ( $AREF eq "" ) { shift(@P6FILES); }
}
foreach my $AREF (@EMFILES) {
   if ( $AREF eq "" ) { shift(@EMFILES); }
}

use File::Basename;
my %P6SEEN = ();
my @P6NOTBUILT = ();
foreach my $ITEM (@P6) { $P6SEEN{$ITEM} = 1; }
foreach my $PKG (@P6FILES) {
   my $BASENAME = basename($PKG);
   unless ($P6SEEN{$BASENAME}) { push (@P6NOTBUILT, $PKG); }
}
my %EMSEEN = ();
my @EMNOTBUILT = ();
foreach my $ITEM (@EM) { $EMSEEN{$ITEM} = 1; }
foreach my $PKG (@EMFILES) {
   my $BASENAME = basename($PKG);
   unless ($EMSEEN{$BASENAME}) { push (@EMNOTBUILT, $PKG); }
}

print "$MAINTRUNK/P6 Packages not built:\n";
foreach my $AREF (@P6NOTBUILT) { print $AREF . "\n"; }
print "\n\n";
print "$MAINTRUNK/EM Packages not built:\n";
foreach my $AREF (@EMNOTBUILT) { print $AREF . "\n"; }
