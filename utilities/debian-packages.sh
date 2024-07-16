#!/usr/bin/env bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }
source "${WKDEV_SDK}/utilities/prerequisites.sh"

verify_executables_exist apt-get dpkg-query

update_packages() { apt-get update; }

add_ppa() {

    local ppa_repo="${1}" # e.g. project/name
    local name="${2}"
    local signing_key="${3}"
    local keyring="/etc/apt/keyrings/${name}.gpg"

    mkdir "${HOME}/.gnupg"
    dirmngr --daemon
    gpg --no-default-keyring --keyring="/etc/apt/keyrings/${name}.gpg" --keyserver=keyserver.ubuntu.com --recv-keys "${signing_key}" || _abort_ "Failed to import key for ${ppa_repo}"
    dirmngr --shutdown
    rm -r "${HOME}/.gnupg"

    echo "deb [signed-by=${keyring}] http://ppa.launchpad.net/${ppa_repo}/ubuntu noble main
deb-src [signed-by=${keyring}] http://ppa.launchpad.net/${ppa_repo}/ubuntu noble main" > "/etc/apt/sources.list.d/${name}.list"
}

is_package_installed() {

    local package="${1}"
    [ $(dpkg-query --show --showformat='${Status}' "${package}" 2>/dev/null | grep --count "ok installed") -eq 0 ] && return 1
}

ensure_package_installed() {

    local package="${1}"
    is_package_installed "${package}" && return 0
    apt-get --assume-yes install "${package}" || _abort_ "Cannot install package '${package}': executing 'apt-get install' failed"
}

upgrade_packages() {

    local packages="${@}"

    apt-get upgrade -y "${packages}" || _abort_ "Cannot upgrade packages '${packages}': executing 'apt-get upgrade' failed"
}
