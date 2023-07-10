#!/usr/bin/env bash
CCACHE_MAX_CAPACITY_IN_GB=8

setup_ccache() {
    echo ""

    export CCACHE_DIR="/builder/cache"
    if [ ! -d "${CCACHE_DIR}" ]; then
        echo "-> Creating new ccache directory '${CCACHE_DIR}' with up to ${CCACHE_MAX_CAPACITY_IN_GB}GB capacity..."
        ccache --max-size "${CCACHE_MAX_CAPACITY_IN_GB}G"
        sudo update-ccache-symlinks
    else
        echo "-> Re-using existing ccache directory '${CCACHE_DIR}'."
    fi
}

setup_proxy() {
    echo ""

    local proxy_host="localhost"
    local proxy_port=8765
    local proxy_url="http://${proxy_host}:${proxy_port}"

    echo "-> Ensure proxy server is reachable at '${proxy_url}'..."
    curl --output /dev/null --silent "${proxy_url}"
    if [ ${?} -eq 0 ]; then
        echo "-> Found proxy server - will cache .deb package downloads."
    else
        echo "-> Cannot contact proxy server '${proxy_url}'. Proceeding without cached .deb package downloads."
    fi
}

setup_ccache
setup_proxy
