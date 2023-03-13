#!/usr/bin/bash

verify_executable_exists() {
    local executable="${1}"
    if ! command -v "${executable}" >/dev/null; then
        printf "\nCannot find required '${executable}' executable.\n"
        exit 1
    fi
}

verify_executables_exist() {
    local executables="${@}"
    for executable in ${executables}; do
        verify_executable_exists "${executable}"
    done
}
