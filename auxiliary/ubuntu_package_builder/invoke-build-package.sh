#!/usr/bin/bash
work_directory=${1}
package_full_name=${2}
debuild_options=${3}

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
fi

${podman_executable} run --network host --rm \
       --mount type=bind,source=${work_directory},destination=/builder/work,rslave \
       --mount type=volume,source=ubuntu-package-builder-22-10-cache,destination=/builder/cache \
       docker.io/nikolaszimmermann/ubuntu-package-builder:22.10 /builder/build-package.sh "${build_profile}" "${package_full_name}" "${debuild_options}"
