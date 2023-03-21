#!/usr/bin/bash

[ -f "${WKDEV_SDK}/.wkdev-sdk-root" ] || { echo "Please set \${WKDEV_SDK} to point to the root of the wkdev-sdk checkout."; exit 1; }

# NOTE: This doesn't make use of utilities/application.sh on purpose.
# This script is intended to be used for CI later and thus needs to
# be revisited anyhow at a later time.

test_container_name="wkdev-bootstrap"
test_home_directory="/tmp/${test_container_name}-home"

# This script is trivial enough to justify 'set -o errexit' usage.
set -o errexit # Exit upon command failure

# Warn about unset variables
set -o nounset

# 1) Build SDK
echo "[1/6] Building SDK..."
${WKDEV_SDK}/scripts/host-only/wkdev-sdk-bakery --mode build --verbose

# 2) Test creation of container
echo ""
echo "[2/6] Creating '${test_container_name}' container with fresh home directory in '${test_home_directory}'..."
${WKDEV_SDK}/scripts/host-only/wkdev-create --verbose --create-home --home "${test_home_directory}" --name "${test_container_name}"

# 3) Test executing a command in the container
uptime_command="uptime --pretty"
echo ""
echo "[3/6] Executing '${uptime_command}' in '${test_container_name}' container..."
${WKDEV_SDK}/scripts/host-only/wkdev-enter --verbose --exec --name "${test_container_name}" -- ${uptime_command}

# 4) Stop container
echo ""
echo "[4/6] Stopping '${test_container_name}' container..."
podman stop "${test_container_name}" &>/dev/null

# 5) Delete container
echo ""
echo "[5/6] Deleting '${test_container_name}' container..."
podman rm --volumes "${test_container_name}" &>/dev/null

# 6) Delete home directory
echo ""
echo "[6/6] Deleting '${test_container_name}' home directory..."
podman unshare rm -rf "${test_home_directory}" &>/dev/null

# 7) Show instructions how to deploy the new SDK image
echo ""
echo "Ready. If everything went well, use 'scripts/host-only/wkdev-sdk-bakery --mode deploy' to push the new SDK image to the registry, once tested!"
