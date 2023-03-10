#!/usr/bin/bash
work_directory=${1}
packages_directory=${2}
package_full_name=${3}
deb_build_options=${4}
dpkg_buildpackage_options=${5}

build_directory="${work_directory}/builds/${package_full_name}"

# Execute the podman conainer from within the host, not from within the container.
# While this works fine for same cases, to build debian packages, it's too tricky,
# so let's avoid rootless-podman-in-rootless-podman scenarios for the package builder.
podman_executable=podman
build_profile="full"
if [ -f /run/.containerenv ]; then
    podman_executable=podman-host
    build_profile="fast"

    # Translate from container home relative path to host path.
    work_directory="${work_directory/${HOME}/${HOST_CONTAINER_HOME_PATH}}"
    packages_directory="${packages_directory/${HOME}/${HOST_CONTAINER_HOME_PATH}}"
fi

${podman_executable} run --network host --rm \
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
