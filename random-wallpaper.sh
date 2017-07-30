#!/bin/bash

wallpaper_dir=~/img-wallpaper
file_cur=/tmp/random-wallpaper.txt
file_log=/tmp/random-wallpaper.log

if [ "$1" = '--backwards' ]; then
   BACKWARDS=true
fi



function chooseWallpaper() {
   wallpaper=$(\
      # find $wallpaper_dir -name '*' -exec file {} \; | grep -o -P '^.+: \w+ image' \
      find $wallpaper_dir -regex '.*\.\(png\|jpg\|jpeg\)' \
      | sed 's/:.*$//' \
      | sort -R | head -n1 \
      )
}


function setWallpaper() {
   feh --bg-scale "$wallpaper"
}


function setWallpaperSymlinkI3() {
   if [[ -L ~/.i3/wallpaper ]]; then
      ln -s -f "$wallpaper" ~/.i3/wallpaper
   fi
   # i3lock needs png
   if ! file "$wallpaper" | grep 'PNG image data' >/dev/null; then
      convert "$wallpaper" ~/.i3/wallpaper.png
   fi
}


if [[ -z $BACKWARDS ]]; then
   chooseWallpaper
   echo "$wallpaper" >> "${file_log}"
else
   n=$(grep --line-number "$(cat "${file_cur}")"  "${file_log}" | cut -d: -f1)
   n=$((n - 1))
   wallpaper=$(sed "${n}q;d" "${file_log}")
fi

echo "$wallpaper"
echo "$wallpaper" > "${file_cur}"

setWallpaper
if [[ $(whoami) = 'sflip' ]]; then
   setWallpaperSymlinkI3
fi
