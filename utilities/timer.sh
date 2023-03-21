#!/usr/bin/bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }
source "${WKDEV_SDK}/utilities/prerequisites.sh"

start_time=0

timer_start() { start_time=${SECONDS}; }

timer_stop() {

    elapsed=$(( SECONDS - start_time ))
    eval "echo Elapsed time: $(date -ud "@$elapsed" +'$((%s/3600/24)) days %H hr %M min %S sec')"
}
