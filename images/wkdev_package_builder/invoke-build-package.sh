#!/usr/bin/env bash

[ -f "${WKDEV_SDK}/.wkdev-sdk-root" ] && source "${WKDEV_SDK}/utilities/application.sh" || { echo "The variable \${WKDEV_SDK} needs to point to the root of the wkdev-sdk checkout."; exit 1; }
init_application "${0}" "Launch a container that runs the 'build-package.sh' script" host-and-container

# Source utility script fragments
source "${WKDEV_SDK}/utilities/podman.sh"
source "${WKDEV_SDK}/utilities/timer.sh"

work_directory="${1}"
packages_directory="${2}"
package_full_name="${3}"
deb_build_options="${4}"

build_directory="${work_directory}/builds/${package_full_name}"
log_file="${build_directory}/build.log"

build_profile="full"
if is_running_in_container; then
    build_profile="fast"

    # Translate from container home relative path to host path.
    work_directory="${work_directory/${HOME}/${HOST_CONTAINER_HOME_PATH}}"
    packages_directory="${packages_directory/${HOME}/${HOST_CONTAINER_HOME_PATH}}"
fi

# Ensure the package proxy service is running...
${WKDEV_SDK}/scripts/wkdev-ensure-package-proxy-service

# ... before invoking package builds.
timer_start
run_podman_in_background_and_log_to_file "${log_file}" run --network host --rm \
    --mount type=bind,source=${work_directory},destination=/builder/work,rslave \
    --mount type=bind,source=${packages_directory},destination=/builder/packages,rslave \
    --mount type=volume,source="$(get_package_builder_image_name)-cache",destination=/builder/cache \
    "$(get_package_builder_qualified_name_and_tag)" /builder/build-package.sh \
    "${build_profile}" "${package_full_name}" "${deb_build_options}"

# Grace period before attempting to tail the log.
sleep 2

background_pid=${!}
tail --lines=10000 --follow --pid=${background_pid} "${log_file}" &
wait ${background_pid} || _abort_ "Build failed"

echo ""
echo "-> Build finished successfully. $(timer_stop)"
