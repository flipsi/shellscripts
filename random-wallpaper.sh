#!/bin/bash

wallpaper_dir=~/img-wallpaper


wallpaper=$(\
# find $wallpaper_dir -name '*' -exec file {} \; | grep -o -P '^.+: \w+ image' \
find $wallpaper_dir -regex '.*\.\(png\|jpg\|jpeg\)' \
| sed 's/:.*$//' \
| sort -R | head -n1 \
)
feh --bg-scale "$wallpaper"
