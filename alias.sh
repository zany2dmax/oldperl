#!/bin/bash

# have the tty output match the who output
TTY=`/usr/bin/tty | /bin/sed '/^\/dev\//!d; s///;q'`
# Find the line of the terminal we are on
THISTERM=`/usr/bin/who | grep $TTY | awk '{ print $5 }'`
if [[ "$THISTERM" == "(:0.0)" ]]; then
   alias vi='gvim '
else 
   alias vi='vim '
fi

