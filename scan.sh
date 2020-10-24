#!/usr/bin/env bash

# Using SANE (https://wiki.archlinux.org/index.php/SANE)

# show available scanners with `scanimage -L`
DEVICE='pixma:MG3600_192.168.0.14'

OUTPUT_FILE="$1"
EXTENSION="${OUTPUT_FILE##*.}"

if [[ -z "$OUTPUT_FILE" ]]; then
    echo "ERROR: Please provide output file."
    exit 1
elif [[ -e "$OUTPUT_FILE" ]]; then
    echo "ERROR: File already exists."
    exit 1
fi

scanimage --device "$DEVICE" --format="$EXTENSION" --output-file "$OUTPUT_FILE" --progress
