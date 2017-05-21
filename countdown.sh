#!/bin/bash

function countdown(){
   date1=$((`date +%s` + $1));
   while [ "$date1" -ge `date +%s` ]; do
     echo -ne "$(date -u --date @$(($date1 - `date +%s`)) +%H:%M:%S)\r";
     sleep 0.1
   done
}

countdown $@

# usage in bash: countdown.sh $((60 * 2))
# usage in fish: countdown.sh (math "60 * 2")

