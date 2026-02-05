#!/usr/bin/env bash
# Copyright 2024 Igalia S.L.
# SPDX-License: MIT

# To be sourced from your e.g. ~/.bashrc / ~.zprofile / ... to integrate wkdev-sdk with your host OS.
my_relpath="${BASH_SOURCE[0]}"
test -z "${my_relpath}" && my_relpath="${0}"
wkdev_sdk_directory="$(readlink -f $(dirname ${my_relpath}))"

export WKDEV_SDK="${wkdev_sdk_directory}"
export PATH="${WKDEV_SDK}/scripts:${WKDEV_SDK}/scripts/host-only:$(python3 -m site --user-base)/bin:${PATH}"

#.
