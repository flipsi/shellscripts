#!/bin/bash

wallpaper_dir=~/img-wallpaper


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

chooseWallpaper
setWallpaper
if [[ $(whoami) = 'sflip' ]]; then
   setWallpaperSymlinkI3
fi
