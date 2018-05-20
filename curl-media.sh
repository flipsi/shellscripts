#!/bin/bash

# Author: "Philipp Moers" <soziflip@gmail.com>

function print_help_msg() {
    cat <<-EOF
List or download media files found on a given website.

Usage: curl-media.sh [-d] URL

    OPTIONS:
    --help     | -h             Don't do anything, just print this help message.
    --download | -d             Actually download files, not just list.

EOF
}


for i in "$@"
do
  case $i in
      -d|--download)
          DOWNLOAD=true
          shift
          ;;
      -h|--help)
          print_help_msg;
          exit 0
          ;;
      -*)
          echo "Unknown option: ${i}"
          exit 1
          ;;
      *)
          URL=${i}
          ;;
  esac
done


if [[ -z $URL ]]; then
    echo "Please provide a URL!"
    exit 1
else
    URL=${URL%/} # remove trailing slash
fi



set -e

FILE_PATTERN='\.(pdf|mp3|mp4|jpg|jpeg|gif|png|flv|mov)$'

FILES=($(\
    curl -s $URL \
    | grep -o "<a href=[^>]*>" \
    | sed -r 's/<a href="([^"]*)".*>/\1/' \
    | sort -u \
    | grep -E -i ${FILE_PATTERN} \
    || true
))

N=${#FILES[@]}

if [[ (${N} -gt 0) ]]; then
    for FILE in ${FILES[*]}; do
        if [[ ${DOWNLOAD} = true ]]; then
            echo "Downloading $FILE..."
            curl $URL/$FILE -o $FILE
        else
            echo "Found $FILE"
        fi
    done
    if [[ -z ${DOWNLOAD} ]]; then
        echo -e "\nSet -d option to actually download ${N} files!"
    fi
else
    echo "Could not find any media files on ${URL}!"
fi

