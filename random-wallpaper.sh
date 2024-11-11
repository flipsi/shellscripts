#!/bin/bash

set -e

# Author: "Philipp Moers" <soziflip@gmail.com>

function print_help_msg() {
    cat <<-EOF
Set a random wallpaper

Usage: random-wallpaper.sh [OPTIONS]

        OPTIONS:
        --help | -h                     Don't do anything, just print this help message.
        --backwards | -b                Restore last recent wallpaper.
        --multi | -m                    Individual wallpaper per output.
        --dir=/path | -d=/path          Directory with wallpapers to choose from.

EOF
}

# TODO: --only option to only set for current output

DEFAULT_WALLPAPER_DIR="$HOME/img-wallpaper/interfacelift"
i3_WALLPAPER="$HOME/.i3/wallpaper.png" # must end with '.png'

function require {
  hash "$1" 2>/dev/null || {
    echo >&2 "Error: '$1' is required, but was not found."; exit 1;
  }
}

require feh
require magick

for i in "$@"
do
    case $i in
        --backwards|-b)
            BACKWARDS=true
            shift
            ;;
        --multi|-m)
            MULTI=true
            shift
            ;;
        --dir=*|-d=*)
            WALLPAPER_DIR="${i#*=}"
            shift
            ;;
        --help|-h)
            print_help_msg;
            exit 0
            ;;
        *)
            echo ERROR: Unknown option!
            exit 1
            ;;
    esac
done


if [[ -z $WALLPAPER_DIR ]]; then
    if [[ -d "$DEFAULT_WALLPAPER_DIR" ]]; then
        WALLPAPER_DIR="$DEFAULT_WALLPAPER_DIR"
    else
        WALLPAPER_DIR=$HOME
    fi
fi

file_cur=/tmp/random-wallpaper.txt
file_log=/tmp/random-wallpaper.log



function chooseWallpaper() {
    if [[ -n $MULTI ]]; then
        N=$(xrandr | grep --count ' connected')
    else
        N=1
    fi
    wallpaper=$(\
        find -L "$WALLPAPER_DIR" -regex '.*\.\(png\|jpg\|jpeg\)' \
            | sed 's/:.*$//' \
            | sort -R | head -n"${N}" \
            | sed 's/$/ /g' | tr -d '\n' )
    wallpaper=$(echo "$wallpaper" | cut -d' ' -f1)
}


function setWallpaper() {
    # feh --bg-scale "$wallpaper"
    feh --bg-fill "$wallpaper"
}


function setWallpaperSymlinkI3() {
    # i3lock needs png
    if file "$wallpaper" | grep 'PNG image data' >/dev/null; then
        ln -s -f "$wallpaper" "$i3_WALLPAPER"
    else
        magick "$wallpaper" -resize 2560x1440 "$i3_WALLPAPER"
    fi
}


function restoreWallpaper() {
    n=$(grep --line-number "$(cat "${file_cur}")"  "${file_log}" | cut -d: -f1)
    n=$((n - 1))
    wallpaper=$(sed "${n}q;d" "${file_log}")
}


if [[ -z $BACKWARDS ]]; then
    chooseWallpaper
    echo "$wallpaper" >> "${file_log}"
else
    restoreWallpaper
fi

echo "$wallpaper"
echo "$wallpaper" > "${file_cur}"

setWallpaper

if [[ -e "$i3_WALLPAPER" ]]; then
    setWallpaperSymlinkI3
fi
