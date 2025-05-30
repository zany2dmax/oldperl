#!/bin/ksh
##########################################################################
# Title      :	fdate - future date
# Author     :	Heiner Steven <heiner.steven@odn.de>
# Date       :	1998-03-17
# Requires   :	gawk
# Category   :  System Utilities
# SCCS-Id.   :	@(#) fdate	1.3 %$%
##########################################################################
# Description
#  o Uses non-standard functions "strftime()" and "systime()"
#    of non-standard program "gawk" to print future dates
# Changes
# 27.05.98 stv	support dates in the past (0.3)	
##########################################################################

PN=`basename "$0"`			# Program name
VER='1.3'

# Default date format
DateFormat="%a, %d %b %Y %H:%M:%S +0100"

usage () {
    echo >&2 "$PN - print future date, $VER (stv '98)
usage: $PN [+dateformat] [timeperiod ...]

dateformat: see the manual page for strftime(3).
timeperiod: seconds to add to/subtract from the current time.

The time period may be specified in one of two ways:
     o  in seconds, i.e. "3600" for one hour
     o  in multiples of minutes, hours, weeks, months, or years i.e.
     		2 weeks 1 day"
    exit 1
}

msg () {
    for msgLine
    do echo "$PN: $msgLine" >&2
    done
}

fatal () { msg "$@"; exit 1; }

# We need GAWKs non-standard extensions systime() and strftime(),
# and we are prepared to search for gawk:
if [ -z "$GAWK" ]
then
    for path in `echo "$PATH" | sed 's|^:|./ |;s|:$| ./|;s|:| |g'`
    do [ -x "$path/gawk" ] && break
    done
    GAWK=$path/gawk
fi
[ -x "$GAWK" ] || fatal "Sorry, cannot find gawk in your PATH"

#set -- `getopt h "$@"`
while [ $# -gt 0 ]
do
    case "$1" in
	--)	shift; break;;
	-h)	usage;;
	-*)	break;;			# could be "-day"
	*)	break;;			# First file name
    esac
    shift
done

case "$1" in
    +*)					# A "+" starts the date format
    	DateFormat=`echo "$1" | sed 's/^+//'`
	shift;;
esac

echo "$@" | tr '[A-Z]' '[a-z]' |
    $GAWK '
        function secondsof(word) {
	    sign = +1
	    if ( word ~ /^-/ ) {
	    	sign = -1
		sub (/^-/, "", word)
	    }
	    sub (/^+/, "", word)	# "+week"
	    sub (/s$/, "", word)	# "weeks" -> "week"
	    for ( shortname in Secs ) {
	    	if ( shortname == word ) {
		    return sign * Secs [word]
		}
	    }
	    return 0
	}

        BEGIN {
	    DateFormat = "'"$DateFormat"'"
	    # Calculate the seconds for common time intervals
	    Secs ["minute"] = Secs ["min"] = 60
	    Secs ["hour"] = 60*60
	    Secs ["day"] = 60*60*24
	    Secs ["week"] = 60*60*24*7
	    Secs ["month"] = int (60*60*24*7*4.25)
	    Secs ["year"] = Secs ["day"] * 365
	    op = ""
	    seconds = 0
	}
	{
	    for ( i=1; i<=NF; i++ ) {
	        number = 0
	        if ( $i ~ /^[-+]$/ ) {
		    op = $i ""
		    continue
		} else if ( $i ~ /^[-+]*[0-9][0-9]*$/ ) {
		    number = $i
		    if ( i < NF && secondsof($(i+1)) ) {
		    	number = number * secondsof($(i+1))
			i++
		    }
		} else if ( secondsof($i) ) {
		    number = secondsof($i)
		} else {
		    print "WARNING: ignoring " $i | "cat >&2"
	 	}
		if ( op == "-" ) {
		    seconds -= number
		} else {
		    seconds += number
		}
	    }
	}
	END {
	    now = systime ()
	    print strftime (DateFormat, now + seconds)
	}
    '

