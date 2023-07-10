#!/usr/bin/env bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }

does_executable_exist() { command -v "${1}" >/dev/null; }

verify_executable_exists() {

    local executable="${1}"
    does_executable_exist "${executable}" || _abort_ "Cannot find required '${executable}' executable"
}

verify_executables_exist() {

    local executables="${@}"
    for executable in ${executables}; do
        verify_executable_exists "${executable}"
    done
}
