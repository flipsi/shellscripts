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
VOLUME_INITIAL=50
VOLUME_INCREMENT_COUNT=8
VOLUME_INCREMENT_FREQUENCY=$((60 * 2))
VOLUME_INCREMENT_AMOUNT=2

AUDIO_SRC= # will be set by arg or picked from pool
AUDIO_SRC_POOL=(\
    http://176.31.248.14:34794 \
    http://192.211.51.158:5014 \
    http://192.96.205.59:7610 \
    http://198.50.158.92:8190 \
    http://199.189.111.28:8012 \
    http://209.236.126.18:8002 \
    http://64.71.79.181:5058 \
    http://66.85.88.18:5284 \
    http://95.211.3.65:8000 \
    http://brainradioklassik.stream.laut.fm/brainradioklassik \
    http://direct.fipradio.fr/live/fip-midfi.mp3 \
    http://listento.thefunkstation.com:8000 \
    http://soulradio02.live-streams.nl:80/live \
    http://stream.srg-ssr.ch/m/rsj/mp3_128 \
    https://www.stream24.net/tune-in/r6247.m3u \
    )
AUDIO_SRC_FALLBACK="/home/sflip/snd/giving-up-the-ghost.flac"

PIDFILE_AUDIO=/tmp/alarm_audio.pid
PIDFILE_VOLUME_INCREMENT=/tmp/alarm_volume_increment.pid



##########
# SCRIPT #
##########


function set_volume() {
    local VOLUME="$1"
    echo "Setting volume: ${VOLUME}%"
    SINK=$(pactl -- list short sinks | cut -f1)
    pactl -- set-sink-volume "${SINK}" "${VOLUME}%"
}


function pick_audio_src() {
    local SRC="$1"
    if [[ -n $SRC ]]; then
        AUDIO_SRC="$SRC"
    else
        AUDIO_SRC=${AUDIO_SRC_POOL[$RANDOM % ${#AUDIO_SRC_POOL[@]}]}
    fi
    if [[ ${AUDIO_SRC} =~ ^http ]]; then
        if ! curl -ILsf "${AUDIO_SRC}" -o/dev/null; then
            echo "Audio source ${AUDIO_SRC} seems unreachable!"
            echo "Using fallback ${AUDIO_SRC_FALLBACK}"
            AUDIO_SRC="${AUDIO_SRC_FALLBACK}"
        fi
    fi

    echo "Audio source is ${AUDIO_SRC}"
}


function start_alarm() {
    set_volume ${VOLUME_INITIAL}

    echo "Starting audio player..."
    cvlc "${AUDIO_SRC}" & echo $! > ${PIDFILE_AUDIO}
    echo "Audio player PID: $(cat ${PIDFILE_AUDIO})"

    # increase volume step by step (in background)
    (
    for (( i = 0; i < VOLUME_INCREMENT_COUNT; i++ )); do
        sleep ${VOLUME_INCREMENT_FREQUENCY}
        set_volume +${VOLUME_INCREMENT_AMOUNT}
    done

    rm ${PIDFILE_VOLUME_INCREMENT}
    ) & echo $! > ${PIDFILE_VOLUME_INCREMENT}
    echo "Volume increment PID: $(cat ${PIDFILE_VOLUME_INCREMENT})"
}


function stop_alarm() {
    for PIDFILE in ${PIDFILE_VOLUME_INCREMENT} ${PIDFILE_AUDIO}; do
        if [[ ! -f ${PIDFILE} ]]; then
            echo "Warning: Did not find pidfile ${PIDFILE}"
        else
            PID=$(cat ${PIDFILE})
            if ps "${PID}" >/dev/null; then
                echo "Killing process with PID ${PID}"
                kill "${PID}" && rm ${PIDFILE}
            else
                echo "Warning: No process found with PID ${PID}"
                rm ${PIDFILE}
            fi
        fi
    done
}


# ensure that pactl works from cron
PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
export PULSE_RUNTIME_PATH

if [[ -z $1 ]]; then
    print_help_msg
elif [[ $1 = "start" ]]; then
    echo "------------------------------------"
    echo "alarm.sh started at $(date +'%F %R')"
    pick_audio_src "$2"
    start_alarm
elif [[ $1 = "stop" ]]; then
    stop_alarm
elif [[ $1 =~ ^[+-]?[0-9]+$ ]]; then
    set_volume "$1"
else
    print_help_msg
fi



