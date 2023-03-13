#!/usr/bin/bash
test_container_name="wkdev-bootstrap"
test_home_directory="/tmp/${test_container_name}-home"

# Bash scripting recommendations
set -o errexit # Exit upon command failure
set -o nounset # Warn about unset variables

# 1) Build SDK
printf "\n-> Building SDK ...\n"
scripts/host-only/wkdev-sdk-build --verbose

# 2) Test creation of container
printf "\n-> Creating '${test_container_name}' container with fresh home directory in '${test_home_directory}'...\n"
if [ -d "${test_home_directory}" ]; then
    podman unshare rm -rf "${test_home_directory}" &>/dev/null
fi

scripts/host-only/wkdev-create --verbose --create-home --home "${test_home_directory}" "${test_container_name}"

# 3) Test entering container
printf "\n-> Entering '${test_container_name}' container...\n"
scripts/host-only/wkdev-enter --verbose --execute "${test_container_name}" uptime --pretty

# 4) Cleanup
printf "\n-> Stopping '${test_container_name}' container...\n"
podman stop "${test_container_name}" &>/dev/null

printf "\n-> Deleting '${test_container_name}' container & home directory...\n"
podman rm "${test_container_name}" &>/dev/null
podman unshare rm -rf "${test_home_directory}" &>/dev/null

# 5) Show instructions how to deploy new SDK image to docker.io
printf "\n\nReady. If everything went well, use \"scripts/host-only/wkdev-sdk-deploy\" to push the new SDK image to the registry, once tested!\n"
