#!/usr/bin/bash

trap '[ "$?" -ne 0 ] && echo "[ERROR] A fatal error occurred. Aborting!"' EXIT

# Bash scripting recommendations
set -o errexit # Exit upon command failure
set -o nounset # Warn about unset variables

# 1) Build image using podman
printf "\n-> Building image...\n"
host_scripts/wkdev-sdk-build

# 2) Test creation of full-fledged distrobox containers
printf "\n-> Creating 'wkdev-bootstrap' container...\n"
host_scripts/wkdev-create --create-home --home /tmp/wkdev-bootstrap-home wkdev-bootstrap

# 3) Cleanup
printf "\n-> Stopping & deleting container...\n"
podman stop wkdev-bootstrap &>/dev/null
podman rm wkdev-bootstrap &>/dev/null
rm -Rf /tmp/wkdev-bootstap-home &> /dev/null

# 4) Show instructions how to deploy new SDK image to docker.io
printf "\n\nReady. If everything went well, use \"host_scripts/wkdev-sdk-deploy\" to push the new SDK image to the registry, once tested!\n"
