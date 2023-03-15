#!/usr/bin/bash

# To be sourced from your e.g. ~/.bashrc / ~.zprofile / ... to integrate wkdev-sdk with your host OS.
wkdev_sdk_directory=$(cd "$(dirname "${0:-${PWD}}")" &>/dev/null && pwd)

export WKDEV_SDK="${wkdev_sdk_directory}"
export PATH="${WKDEV_SDK}/scripts:${WKDEV_SDK}/scripts/host-only:$(python3 -m site --user-base)/bin:${PATH}"
