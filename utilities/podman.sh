#!/usr/bin/env bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }
source "${WKDEV_SDK}/utilities/prerequisites.sh"

podman_executable="/usr/bin/podman"
if is_running_in_wkdev_sdk_container; then
    # Requires the presence of /usr/bin/podman-host in the container image.
    # It acts as portal to access the host podman instance.
    podman_executable="/usr/bin/podman-host"
fi

# systemctl to check the presence of a 'podman.socket' user service
# podman, to control, well, podman. :-)
verify_executables_exist systemctl

verify_podman_is_acceptable "${podman_executable}"

# Uses host podman no matter if executed within container or on host.
run_podman() { run_command "${podman_executable}" "${@}"; }
run_podman_silent() { run_command_silent "${podman_executable}" "${@}"; }
run_podman_silent_unless_verbose() { run_command_silent_unless_verbose "${podman_executable}" "${@}"; }
run_podman_silent_unless_verbose_or_abort() { run_command_silent_unless_verbose_or_abort "${podman_executable}" "${@}"; }

run_podman_in_background_and_log_to_file() {

    local log_file="${1}"
    local command="${2}"
    shift 2

    run_podman "${command}" "${@}" &> "${log_file}" &
}

# Queries the container status - stores result in global 'last_container_status' variable.
get_podman_container_status() {

    local container_name="${1}"
    run_podman inspect --type container --format "{{.State.Status}}" "${container_name}" 2>/dev/null
}

# Get the parameters passed to wkdev-init from an existing container.
get_podman_container_init_arguments() {

    local container_name="${1}"
    run_podman inspect --type container --format "{{range .Args}}{{.}} {{end}}" "${container_name}" 2>/dev/null
}

# Get the location where the home directory for a container is stored on the host.
get_podman_container_home_directory_on_host() {

    local container_name="${1}"
    local extract_variable="HOST_CONTAINER_HOME_PATH"
    set -o pipefail
    run_podman inspect --type container "${container_name}" 2>/dev/null | grep "${extract_variable}" | sed -e "s/.*${extract_variable}=//" | sed -e s'/",//' | head --lines 1
    local podman_status=${?}
    set +o pipefail
    return ${podman_status}
}

# Get currently used image name given an container name.
get_image_name_by_container_name() {

    local container_name="${1}"
    run_podman inspect --type container --format "{{.ImageName}}" "${container_name}" 2>/dev/null
}

# Get currently used image ID given an container name.
get_image_id_by_container_name() {

    local container_name="${1}"
    run_podman inspect --type container --format "{{.Image}}" "${container_name}" 2>/dev/null
}

# Get most recent known image ID given an image name.
get_image_id_by_image_name() {

    local image_name="${1}"
    run_podman inspect --type image --format "{{.Id}}" "${image_name}" 2>/dev/null
}

# Get list of all containers by name.
get_list_of_containers() { run_podman container list --all --format "{{.Names}}"; }

# Does the podman user socket exist?
is_podman_user_socket_available() {

    local podman_socket="${XDG_RUNTIME_DIR-}/podman/podman.sock"

    # The socket has to exist...
    [ -S "${podman_socket}" ] || return 1

    # ... and it should be controlled by the systemd user session.
    systemctl status --user podman.socket &>/dev/null
    return ${?}
}
