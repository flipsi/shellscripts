#!/bin/bash

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


set -e

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
    if [[ -d $HOME/img-wallpaper ]]; then
        WALLPAPER_DIR=$HOME/img-wallpaper
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
        # find $WALLPAPER_DIR -name '*' -exec file {} \; | grep -o -P '^.+: \w+ image' \
        find $WALLPAPER_DIR -regex '.*\.\(png\|jpg\|jpeg\)' \
            | sed 's/:.*$//' \
            | sort -R | head -n${N} \
            | sed 's/$/ /g' | tr -d '\n' )
}


function setWallpaper() {
    feh --bg-scale $wallpaper
}


function setWallpaperSymlinkI3() {
    local wallpaper=$(echo $wallpaper | cut -d' ' -f1)
    if [[ -L ~/.i3/wallpaper ]]; then
        ln -s -f "$wallpaper" ~/.i3/wallpaper
    fi
    # i3lock needs png
    if ! file "$wallpaper" | grep 'PNG image data' >/dev/null; then
        convert "$wallpaper" ~/.i3/wallpaper.png
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

echo $wallpaper
echo $wallpaper > "${file_cur}"

setWallpaper
if [[ $(whoami) = 'sflip' ]]; then
    wallpaper=$(echo $wallpaper | cut -f1 -d' ')
    setWallpaperSymlinkI3
fi
