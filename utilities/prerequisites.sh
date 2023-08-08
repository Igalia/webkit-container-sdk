#!/usr/bin/env bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }

does_executable_exist() { command -v "${1}" >/dev/null; }

verify_executable_exists() {

    local executable="${1}"
    does_executable_exist "${executable}" || _abort_ "Cannot find required '${executable}' executable"
}

is_version_greater_or_equal() { [ "$(printf '%s\n' "${@}" | sort -V | head -n 1)" != "${1}" ]; }

verify_podman_is_acceptable() {

    local executable="${1}"
    verify_executable_exists "${executable}"

    local -r required_version="4.0.0"
    local podman_version
    podman_version=$("${executable}" --version | awk '{print $3}')
    is_version_greater_or_equal "${podman_version}" "${required_version}" || _abort_ "'${executable}' version '${podman_version}' is older than required '${required_version}'"
}

verify_executables_exist() {

    local executables="${@}"
    for executable in ${executables}; do
        verify_executable_exists "${executable}"
    done
}
