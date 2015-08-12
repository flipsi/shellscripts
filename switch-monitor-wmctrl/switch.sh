#!/bin/bash

#get the window geometry
widthHeight=( $(wmctrl -l  -G | grep -v ' \-1 ' | awk 'END{print $5,$6}' ))

#toggle if $1 is set and set to left - move window to left
if [[ ! -z $1 ]]; then
        if [[ $1 == "left" ]]; then
        #this window is in another screen
        wmctrl -r ":ACTIVE:" -e 0,0,0,${widthHeight[0]},${widthHeight[1]}
        fi
else
#else move window to right
        wmctrl -r ":ACTIVE:" -e 0,1920,0,${widthHeight[0]},${widthHeight[1]}
fi