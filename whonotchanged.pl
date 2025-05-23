#!/usr/bin/perl -w
# Has to be run by root to read /etc/shadow
# See Jeff Leggett, Security Engineering if you have questions

use strict;
use Passwd::Linux qw(mgetpwnam);

my %USERLIST;

open ORIGSHADOW, "< /home/sys/ubersys/shadow";
while (<ORIGSHADOW>) {
    (my $USER, my $PASSWD, my $REST) = split /:/, $_, 3;
    $USERLIST{$USER} = $PASSWD;
}
close ORIGSHADOW;

open NAMEONLY, " >usernames.txt";
open CURRSHADOW, "< /etc/shadow";
print NAMEONLY "User, Domain\n";
while (<CURRSHADOW>) {
    my @TMP = split (/:/, $_);
    if ( $TMP[1] eq $USERLIST{$TMP[0]} ) {
	my @PWDATA = mgetpwnam("$TMP[0]");
        print NAMEONLY "$TMP[0],$PWDATA[4]\n";
    }
}
close CURRSHADOW;
close NAMEONLY;

