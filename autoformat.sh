#!/usr/bin/env bash

set -e

filename="$1"

if [[ -z "$filename" ]]; then
    echo "ERROR: Please provide at least one file"
    exit 1
fi

extension="${filename##*.}"

case "$extension" in
    scala|sc )
        scalafmt "$@"
        ;;
    * )
        echo "ERROR: No formatter found for extension .$extension"
        exit 1
        ;;
esac
