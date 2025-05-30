#------------------------------------------------------------------------
# ISO 6429 character sequences for colors etc
# lc = leading character sequence, common for all colors.
lc='\[\e[1;'
# foregrounds----backgrounds--------------------------------------------------
BLACK=${lc}30m;  B_BLACK=${lc}40m
RED=${lc}31m;    B_RED=${lc}41m
GREEN=${lc}32m;  B_GREEN=${lc}42m
YELLOW=${lc}33m; B_YELLOW=${lc}43m
BLUE=${lc}34m;   B_BLUE=${lc}44m
PURPLE=${lc}35m; B_PURPLE=${lc}45m
CYAN=${lc}36m;   B_CYAN=${lc}46m
WHITE=${lc}37m;  B_WHITE=${lc}47m
#------------------------------------------------------------------
BRIGHT=${lc}1m
UNDER=${lc}4m
FLASH=${lc}5m
RC=${lc}0m  # reset character
SEP="\\\$"  # separator
#------------------------------------------------------------------------
if [ "x${LOGNAME}" = "x" ]
then
  LOGNAME=$(whoami)
fi

# set pc, the prompt color
if [ "$USER" = "root" ]
then
  pc=$RED
else
  pc=$PURPLE
fi
#------------------------------------------------------------------------

# set the prompt
if [ $TERM  = "dumb" ]
then
  # no color if a dumb terminal
  pc=""; RC=""
fi

PS1="${pc}\]\u@\h \W\\$ ${RC}\]"
#PS1="${pc}\][\u@\h \w]$SEP${RC} "
#------------------------------------------------------------------------

