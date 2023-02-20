#!/usr/bin/bash
work_directory=${1}
package_full_name=${2}
debuild_options=${3}

# Be sure to execute this from the host, if we're running in the wkdev-sdk container.
podman_executable=podman
if [ -f /run/.containerenv ]; then
    podman_executable=podman-host

    # Translate from container home relative path to host path.
    work_directory="${work_directory/${HOME}/${HOST_CONTAINER_HOME_PATH}}"
fi

${podman_executable} run --network host --rm \
       --mount type=bind,source=${work_directory},destination=/builder/work,rslave \
       --mount type=volume,source=ubuntu-package-builder-22-10-cache,destination=/builder/cache \
       docker.io/nikolaszimmermann/ubuntu-package-builder:22.10 /builder/build-package.sh "${package_full_name}" "${debuild_options}"
