#!/usr/bin/env bash

# In a directory, containing a flac/ape/wv file with multiple tracks (album)
# and a cue file, split it in multiple flac files.

# Author: Philipp Moers <soziflip@gmail.com>


######################
# CHECK DEPENDENCIES #
######################

if ! (command -v flac >/dev/null 2>&1); then
    (>&2 echo 'Please install `flac` on your system.')
    exit 3
fi
if ! (command -v ffmpeg >/dev/null 2>&1); then
    (>&2 echo 'Please install `ffmpeg` on your system.')
    exit 3
fi
if ! (command -v bchunk >/dev/null 2>&1); then
    (>&2 echo 'Please install `bchunk` on your system.')
    exit 3
fi



###########
# PREPARE #
###########

# file to split
FILE_TO_SPLIT=$1
if [[ -z "$FILE_TO_SPLIT" ]]; then
    FILE_TO_SPLIT=$(basename -z *.flac)
fi
if [[ ! -f "$FILE_TO_SPLIT" ]]; then
    FILE_TO_SPLIT=$(basename -z *.ape)
fi
if [[ ! -f "$FILE_TO_SPLIT" ]]; then
    FILE_TO_SPLIT=$(basename -z *.wv)
fi
if [[ ! -f "$FILE_TO_SPLIT" ]]; then
    (>&2 echo 'No (or more than one) flac or ape file found.')
    exit 1
fi
FILE_TO_SPLIT_EXTENSION="${FILE_TO_SPLIT##.*}"
FILE_TO_SPLIT_BASE="${FILE_TO_SPLIT%.*}"

# cue file with split information
FILE_CUE=$(basename -z *.cue)
if [[ ! -f "$FILE_CUE" ]]; then
    (>&2 echo 'No cue file found.')
    exit 1
fi




#########
# DO IT #
#########


# WORKING_DIR="/tmp/lala"
# (flac --output-prefix seems to have bugs, so we use the current dir)
WORKING_DIR="."

# convert to wave
ffmpeg -i "$FILE_TO_SPLIT" "$WORKING_DIR/$FILE_TO_SPLIT_BASE.wav"

# split the new wave file
bchunk -w "$WORKING_DIR/$FILE_TO_SPLIT_BASE.wav" "$FILE_CUE" "$WORKING_DIR/$FILE_TO_SPLIT_BASE"

# delete the long wav file
rm -f "$WORKING_DIR/$FILE_TO_SPLIT_BASE.wav"

# and convert back to flac
# flac --best --output-prefix="./"  "$WORKING_DIR/$FILE_TO_SPLIT_BASE"*
# (flac --output-prefix seems to have bugs, so we use the current dir)
flac --best "$WORKING_DIR/$FILE_TO_SPLIT_BASE"*wav

# delete the wav files
# WARNING: THIS MAY ALSO DELETE AN ORIGINAL WAV FILE
rm -f "$WORKING_DIR/$FILE_TO_SPLIT_BASE"*.wav


