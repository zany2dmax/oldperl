#!/usr/bin/perl -w
#
# Script to Audit the monthly user list for Internal Controls
# 1/7/05 Jeff Leggett Security Engineering
#
# Modified 1/21/05 to add Group membership listings
use strict;

my %USERS;
my @TMP;
my $LNAME;

# Create the inital hash....
# This allows us to make sure that the entire alphabet is there.
# This way, you won't have any gaps in the hash but you may have
# empty letters, which is fine.
foreach ("a".."z") {
    $USERS{$_} = undef;
}

open (READ_PW, "/etc/passwd") or die "Can't open /etc/passwd:$!\n";
while (<READ_PW>) {
    @TMP = split(/:/, $_);
    $TMP[0] =~ /^.(.)/; # Grab the second letter of the username.
    # Create a complex hash that is:
    # SecondLetterOfName -> Username  = GCOS
    $USERS{$1}{$TMP[0]} = $TMP[4];
        }
close (READ_PW);

#
# Slurp the Group file
#
my @GRP;
open GRPFILE, "< /etc/group" or die "Can't open /etc/group:$!\n";
while (<GRPFILE>) { push @GRP, $_; } close GRPFILE;

# Work through each letter of the alphabet and print the upper case
# version of the letter that you're working with because UC is easier to
# read than lc in this case...
open AUDITFILE, "> /tmp/userlist.txt" or die "Can't open output file:$!\n";
foreach my $LETTER (sort keys %USERS) {
    print AUDITFILE uc($LETTER) . "\n";
    # For each letter, there will be a sub-hash (or empty key)
    # that we can run through and print the usernames and GCOS information.
    foreach my $LASTNAME (sort keys %{$USERS{$LETTER}}) {
        print AUDITFILE "\t$LASTNAME : $USERS{$LETTER}{$LASTNAME}\n";
        foreach my $LINE ( @GRP ) {
           if ($LINE =~ /$LASTNAME/) {
	       (my $GRPNAME, my $JUNK, my $GID, my $USERS) = split /:/, $LINE;
	       if ($GRPNAME ne $LASTNAME) {
	           print AUDITFILE "\t  Member of Group: $GRPNAME\n";
               }
	   }
        }
    }
}
close AUDITFILE;

my $MAILPRG = undef;
my $HOSTNAME = `hostname -s`;
my $MAILTOLIST = "internalcontrols\@interland.com";
# For testing
# my $MAILTOLIST = "jleggett\@interland.com";

if ( -e "/bin/mail" ) { $MAILPRG = "/bin/mail"; }
elsif ( -e "/usr/bin/mail" ) { $MAILPRG = "/usr/bin/mail"; }
system ("$MAILPRG -s \"$HOSTNAME User Audit\" $MAILTOLIST < /tmp/userlist.txt");
system ("rm /tmp/userlist.txt");
