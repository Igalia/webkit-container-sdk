#!/usr/bin/bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source utilities/application.sh before sourcing this script." && return 1; }

verify_executable_exists() {
    local executable="${1}"
    if ! command -v "${executable}" >/dev/null; then
        _abort_ "Cannot find required '${executable}' executable"
    fi
}

verify_executables_exist() {
    local executables="${@}"
    for executable in ${executables}; do
        verify_executable_exists "${executable}"
    done
}
