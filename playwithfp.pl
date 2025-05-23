#!/usr/bin/perl

use Passwd::Linux qw(modpwinfo mgetpwnam);

my $MIN_UID = 999;  # Only change passwords greater than this UID

open USERNAMES, "< usernames2.txt" or die "Can't open usernames.txt\n";
while (<USERNAMES>) {
    (my $USER, my $DOMAIN) = split /,/,$_,2;
#    print "Processing user $USER : $DOMAIN";
    my @PWDATA = mgetpwnam("$USER");
    if ( $PWDATA[2] > $MIN_UID ) {
        my $FPDIR = $PWDATA[5] . "/html/_vti_pvt";
        if ( -e "$FPDIR/service.pwd" ) { # Frontpage extensions are installed
            open FPPWDFILE, "<  $FPDIR/service.pwd";
	    open TMPFILE, "> /tmp/tmpfile";
            while (<FPPWDFILE>) {
		if ($_ =~ m/^#/) { print TMPFILE $_; } 
		else {
	 	    (my $FPNAME, my $FPPWD) = split /:/, $_, 2;
		    print TMPFILE "$FPNAME:$FPPWD";
		}
	    }
	    close FPPWDFILE;
	    close TMPFILE;
	}
    }
}


