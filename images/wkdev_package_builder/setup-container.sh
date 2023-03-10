#!/usr/bin/bash
CCACHE_MAX_CAPACITY_IN_GB=8

setup_ccache() {
    export CCACHE_DIR="/builder/cache"

    if [ ! -d "${CCACHE_DIR}" ]; then
        printf "\n-> Creating new ccache directory '${CCACHE_DIR}' with up to ${CCACHE_MAX_CAPACITY_IN_GB}GB capacity...\n"
        ccache --max-size ${CCACHE_MAX_CAPACITY_IN_GB}G
        sudo update-ccache-symlinks
    else
        printf "\n-> Re-using existing ccache directory '${CCACHE_DIR}'.\n"
    fi
}

setup_proxy() {
    local proxy_host="localhost"
    local proxy_port=8765
    local proxy_url="http://${proxy_host}:${proxy_port}"
    printf "\n-> Ensure proxy server is reachable at '${proxy_url}'...\n"

    set +o errexit
    curl --output /dev/null --silent "${proxy_url}"
    curl_status=${?}
    set -o errexit
    if [ ${curl_status} -eq 0 ]; then
        printf "\n-> Found proxy server - will cache .deb package downloads.\n"
        echo "Acquire::http::Proxy \"${proxy_url}\";" | sudo tee /etc/apt/apt.conf.d/squid-deb-proxy &>/dev/null
    else
        printf "\n-> Cannot contact proxy server '${proxy_url}'. Proceeding without cached .deb package downloads.\n"
    fi
}

setup_ccache
setup_proxy
