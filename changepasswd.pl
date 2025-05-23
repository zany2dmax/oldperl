#!/usr/bin/perl
# See Jeff Leggett, Security Engineering if you have questions
# this takes the OUTPUT of the whonotchanged.pl text file created
# and sets a random password for that user.  It creates a text file of 
# passwords with each user for giving them to customers when they call
# It sets the password for both the regular login and for Front Page 
# extensions if they exist

use strict;
use Digest::MD5 qw(md5_hex);
use Passwd::Linux qw(modpwinfo mgetpwnam);

my $MIN_UID = 999;  # Only change passwords greater than this UID

open CSVOUTPUT, " >changedusers.csv";
print CSVOUTPUT "User,Domain,Password\n";
open USERNAMES, "< usernames.txt" or die "Can't open usernames.txt\n";
while (<USERNAMES>) {
    (my $USER, my $DOMAIN) = split /,/,$_,2;
    my @PWDATA = mgetpwnam("$USER");
    if ( $PWDATA[2] > $MIN_UID ) {
	my $SALT = md5_hex(&randpass(38));
	my $PASS = &randpass;
	my $CRYPTED = crypt($PASS,$SALT);
        my $FPDIR = $PWDATA[5] . "/html/_vti_pvt";
	my $FPPWD = $FPDIR . "/service.pwd";
	my $TMPF = $FPDIR . "/tmpfile";
	$PWDATA[1] = $CRYPTED;   
	my $ERR = modpwinfo(@PWDATA);
        if ( -e "$FPDIR/service.pwd" ) { # Frontpage extensions are installed
            open FPPWDFILE, "<  $FPPWD";
            open TMPFILE, "> $TMPF";
            while (<FPPWDFILE>) {
                if ($_ =~ m/^#/) { print TMPFILE $_; }
                else {
                    (my $FPNAME, my $FPPWD) = split /:/, $_, 2;
                    print TMPFILE "$FPNAME:$CRYPTED";
                }
            }
            close FPPWDFILE;
            close TMPFILE;
	    rename($FPPWD, "$FPPWD.orig");
	    chown((getpwnam($USER))[2,3], "$FPPWD.orig");
	    chmod(0666, "$FPPWD.orig");
	    rename($TMPF, $FPPWD);
	    chown((getpwnam($USER))[2,3], $FPPWD);
	    chmod(0666, "$FPPWD");
        }
	print "User $PWDATA[0]'s with domain $PWDATA[4] password reset to: $PASS\n";
	print CSVOUTPUT "$PWDATA[0],$PWDATA[4],$PASS\n";
	printf ("%s\n", $ERR ? "Password update failed: $ERR" : "Password changed successfully");
    }
}
close USERNAMES;
close CSVOUTPUT;

sub randpass {
    my $length = shift;
    $length ||= 10;
    my @chars = ();
    my $password;
    my $rand;
    foreach ('a'..'z','A'..'Z',0..9) { push @chars, $_; }
    push @chars, split(",","-,_,%,#,|,!, ");
    srand;
    for (my $i=0; $i < $length; $i++) {
       $rand = int(rand $#chars);
       $password .= $chars[$rand];
    }
    return $password;
}

