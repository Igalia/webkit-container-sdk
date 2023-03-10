#!/usr/bin/bash
sdk_directory=${1}
work_directory=${2}
packages_directory=${3}
package_full_name=${4}
deb_build_options=${5}
dpkg_buildpackage_options=${6}

build_directory="${work_directory}/builds/${package_full_name}"

build_profile="full"
if [ -f /run/.containerenv ]; then
    build_profile="fast"

    # Translate from container home relative path to host path.
    work_directory="${work_directory/${HOME}/${HOST_CONTAINER_HOME_PATH}}"
    packages_directory="${packages_directory/${HOME}/${HOST_CONTAINER_HOME_PATH}}"
fi

source "${sdk_directory}/utilities/podman.sh"

# Ensure the package proxy service is running...
${sdk_directory}/scripts/wkdev-ensure-package-proxy-service --verbose

# ... before invoking package builds.
call_podman run --network host --rm \
       --mount type=bind,source=${work_directory},destination=/builder/work,rslave \
       --mount type=bind,source=${packages_directory},destination=/builder/packages,rslave \
       --mount type=volume,source=wkdev-package-builder-cache,destination=/builder/cache \
       docker.io/nikolaszimmermann/wkdev-package-builder:22.10 /builder/build-package.sh \
       "${build_profile}" "${package_full_name}" "${deb_build_options}" "${dpkg_buildpackage_options}" &> "${build_directory}/build.log" &

build_pid=${!}
tail --follow --pid=${build_pid} "${build_directory}/build.log" &

wait ${build_pid}
build_status=${?}

if [ ${build_status} -ne 0 ]; then
    printf "\n-> Build failed. Aborting with exit code ${build_status}.\n"
    exit ${build_status}
fi

printf "\n-> Build finished successfully.\n"
