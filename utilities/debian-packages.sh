#!/usr/bin/env bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }
source "${WKDEV_SDK}/utilities/prerequisites.sh"

verify_executables_exist apt-get dpkg-query

update_packages() { apt-get update; }

is_package_installed() {

    local package="${1}"
    [ $(dpkg-query --show --showformat='${Status}' "${package}" 2>/dev/null | grep --count "ok installed") -eq 0 ] && return 1
}

ensure_package_installed() {

    local package="${1}"
    is_package_installed "${package}" && return 0
    apt-get --assume-yes install "${package}" || _abort_ "Cannot install package '${package}': executing 'apt-get install' failed"
}
