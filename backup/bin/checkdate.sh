#!/bin/bash

#ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "
vday=$(date +"%u")


printf 'Day is %s . \n'  "$vday"

vhour=$(date +"%H")
printf 'Hour is %s ' "$vhour"

vmin=$(date +"%M")
printf 'Minute is %s ' "$vmin"

exit