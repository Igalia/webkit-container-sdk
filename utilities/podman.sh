#!/usr/bin/bash

source "${sdk_directory}/utilities/prerequisites.sh"

podman_executable="/usr/bin/podman"
if [ -f /run/.containerenv ]; then
    # Requires the presence of /usr/bin/podman-host in the container image.
    # It acts as portal to access the host podman instance.
    podman_executable="/usr/bin/podman-host"
fi

verify_executable_exists ${podman_executable}

# Uses host podman no matter if executed within container or on host.
call_podman() {
    ${podman_executable} "${@}"
}

# Queries the container status - stores result in global 'last_container_status' variable.
check_podman_container_status() {
    local container_name=${1}
    eval "$(${podman_executable} inspect --type container "${container_name}" --format 'last_container_status={{.State.Status}};' 2>/dev/null)"
}
