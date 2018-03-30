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

VOLUME_INITIAL=25
VOLUME_INCREMENT_COUNT=8
VOLUME_INCREMENT_FREQUENCY=$((60 * 2))
VOLUME_INCREMENT_AMOUNT=2

AUDIO_SRC= # will be picked from pool
AUDIO_SRC_POOL=(\
    http://addrad.io/4WRNm5 \
    http://brainradioklassik.stream.laut.fm/brainradioklassik \
    http://direct.fipradio.fr/live/fip-midfi.mp3 \
    http://direct.fipradio.fr/live/fip-webradio2.mp3 \
    http://mp3channels.webradio.antenne.de/90er-hits \
    http://mp3channels.webradio.antenne.de:80/antenne \
    http://rock-high.rautemusik.fm \
    )

PIDFILE_START=/tmp/alarm.pid
PIDFILE_AUDIO=/tmp/alarm_audio.pid
LOGFILE_AUDIO_1=/tmp/alarm_audio.log
LOGFILE_AUDOI_2=/tmp/alarm_audio.error.log



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
    echo "Audio source is ${AUDIO_SRC}"
}


function start_alarm() {
    local src="$1"
    echo "Alarm started with PID: $$"
    echo $$ > ${PIDFILE_START}

    set_volume ${VOLUME_INITIAL}

    echo "Starting audio player... (logs to ${LOGFILE_AUDIO_1} and ${LOGFILE_AUDOI_2})"
    cvlc "${AUDIO_SRC}" >${LOGFILE_AUDIO_1} 2>${LOGFILE_AUDOI_2} & echo $! > ${PIDFILE_AUDIO}
    echo "Audio player PID: $(cat ${PIDFILE_AUDIO})"

    for (( i = 0; i < ${VOLUME_INCREMENT_COUNT}; i++ )); do
        sleep ${VOLUME_INCREMENT_FREQUENCY}
        set_volume +${VOLUME_INCREMENT_AMOUNT}
    done

    rm ${PIDFILE_START}
}


function stop_alarm() {
    for PIDFILE in ${PIDFILE_START} ${PIDFILE_AUDIO}; do
        if [[ ! -f ${PIDFILE} ]]; then
            echo "Error! Did not find pidfile ${PIDFILE}"
        else
            kill $(cat ${PIDFILE}) && rm ${PIDFILE}
        fi
    done
}


if [[ -z $1 ]]; then
    print_help_msg
elif [[ $1 = "start" ]]; then
    pick_audio_src $2
    start_alarm
elif [[ $1 = "stop" ]]; then
    stop_alarm
elif [[ $1 =~ ^-?[0-9]+$ ]]; then
    set_volume $1
else
    print_help_msg
fi



