#!/bin/bash

# Author: "Philipp Moers" <soziflip@gmail.com>


function print_help_msg() {
    cat <<-EOF
alarm.sh - Playing some audio with increasing volume

Usage:
    alarm-ctl.sh start [URL]     # start alarm
    alarm-ctl.sh stop            # stop alarm
    alarm-ctl.sh <0-100>         # set volume

EOF
}


##########
# CONFIG #
##########

# TODO: adjust and normalize volume for pool
VOLUME_INITIAL=25
VOLUME_INCREMENT_COUNT=8
VOLUME_INCREMENT_FREQUENCY=$((60 * 2))
VOLUME_INCREMENT_AMOUNT=2

AUDIO_SRC= # will be set by arg or picked from pool
AUDIO_SRC_POOL=(\
    http://brainradioklassik.stream.laut.fm/brainradioklassik \
    http://direct.fipradio.fr/live/fip-midfi.mp3 \
    http://direct.fipradio.fr/live/fip-webradio2.mp3 \
    http://mp3channels.webradio.antenne.de/90er-hits \
    http://mp3channels.webradio.antenne.de:80/antenne \
    )
AUDIO_SRC_FALLBACK="/home/sflip/snd/giving-up-the-ghost.flac"

PIDFILE_START=/tmp/alarm.pid
PIDFILE_AUDIO=/tmp/alarm_audio.pid



##########
# SCRIPT #
##########


function set_volume() {
    local VOLUME="$1"
    echo "Setting volume: ${VOLUME}%"
    pactl -- set-sink-volume 0 ${VOLUME}%
}


function pick_audio_src() {
    local SRC="$1"
    if [[ -n $SRC ]]; then
        AUDIO_SRC="$SRC"
    else
        AUDIO_SRC=${AUDIO_SRC_POOL[$RANDOM % ${#AUDIO_SRC_POOL[@]}]}
    fi
    if [[ ${AUDIO_SRC} =~ ^http ]]; then
        if ! curl -ILsf ${AUDIO_SRC} -o/dev/null; then
            echo "Audio source ${AUDIO_SRC} seems unreachable!"
            echo "Using fallback ${AUDIO_SRC_FALLBACK}"
            AUDIO_SRC=${AUDIO_SRC_FALLBACK}
        fi
    fi

    echo "Audio source is ${AUDIO_SRC}"
}


function start_alarm() {
    echo $$ > ${PIDFILE_START}

    set_volume ${VOLUME_INITIAL}

    echo "Starting audio player..."
    cvlc "${AUDIO_SRC}" & echo $! > ${PIDFILE_AUDIO}
    echo "Audio player PID: $(cat ${PIDFILE_AUDIO})"

    # increase volume step by step (in background)
    (
    for (( i = 0; i < ${VOLUME_INCREMENT_COUNT}; i++ )); do
        sleep ${VOLUME_INCREMENT_FREQUENCY}
        set_volume +${VOLUME_INCREMENT_AMOUNT}
    done

    rm ${PIDFILE_START}
    ) &
}


function stop_alarm() {
    for PIDFILE in ${PIDFILE_START} ${PIDFILE_AUDIO}; do
        if [[ ! -f ${PIDFILE} ]]; then
            echo "Error! Did not find pidfile ${PIDFILE}"
        else
            echo "Killing process with PID $(cat ${PIDFILE})"
            kill $(cat ${PIDFILE}) && rm ${PIDFILE}
        fi
    done
}


if [[ -z $1 ]]; then
    print_help_msg
elif [[ $1 = "start" ]]; then
    echo "------------------------------------"
    echo "alarm.sh started at $(date +'%F %R')"
    pick_audio_src $2
    start_alarm
elif [[ $1 = "stop" ]]; then
    stop_alarm
elif [[ $1 =~ ^[+-]?[0-9]+$ ]]; then
    set_volume $1
else
    print_help_msg
fi



