#!/usr/bin/env bash

SCRIPTNAME=$(basename "$0")

set -e

if [[ $1 = "--help" ]]; then
    echo "Usage: $SCRIPTNAME <FILE> [<CHUNK_SIZE>]"
    exit 0
elif [[ -z $1 ]]; then
    echo "Please provide a filename!"
    exit 2
fi


split_csv() {
    HEADER=$(head -1 "$1")
    if [ -n "$2" ]; then
        CHUNK=$2
    else
        CHUNK=1000
    fi
    tail -n +2 "$1" | split -d -l $CHUNK - "$1".part.
    for i in "$1".part.*; do
        sed -i -e "1i$HEADER" "$i"
    done
}

split_csv "$1" "$2"
