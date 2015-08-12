#!/bin/bash
# NOTE: not every terminal supports 256 colors!
# NOTE: tmux has to be started with -2
for i in {0..255} ; do
    printf "\x1b[38;5;${i}mcolour${i}\n"
done