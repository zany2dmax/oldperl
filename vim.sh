#!/bin/bash
if [ -n "$(echo $1 | grep /pl$/)" ]; then
alias vi='vim $1; perl -c $1'
else 
alias vi='vim $1'
fi
