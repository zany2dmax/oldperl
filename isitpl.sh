#!/bin/ksh

filename=$1
ispl=$(echo $filename | grep -c pl$)
if [ "$ispl" = "1" ]; then
    /usr/bin/perl -c $filename
fi
