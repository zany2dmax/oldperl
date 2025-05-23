sub pinghost {
	print $_[0];
	    `ping -n 1 $_[0] ` =~ /Received = 1/ ? 0 : 1;
}
open PINGFILE, "Windows2003list.txt";
while (<PINGFILE>) {
if (pinghost($_) ==  0) { print "is alive!\n"; } else {print "Not pinging!\n" }
}
