#!/usr/bin/bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }
source "${WKDEV_SDK}/utilities/prerequisites.sh"

podman_executable="/usr/bin/podman"
if is_running_in_container; then
    # Requires the presence of /usr/bin/podman-host in the container image.
    # It acts as portal to access the host podman instance.
    podman_executable="/usr/bin/podman-host"
fi

# systemctl to check the presence of a 'podman.socket' user service
# podman, to control, well, podman. :-)
verify_executables_exist systemctl ${podman_executable}

# Uses host podman no matter if executed within container or on host.
run_podman() { run_command "${podman_executable}" ${@}; }
run_podman_silent() { run_command_silent "${podman_executable}" ${@}; }
run_podman_silent_unless_verbose() { run_command_silent_unless_verbose "${podman_executable}" ${@}; }

run_podman_in_background_and_log_to_file() {

    local log_file="${1}"
    local command="${2}"
    shift 2

    run_podman "${command}" ${@} &> "${log_file}" &
}

# Queries the container status - stores result in global 'last_container_status' variable.
check_podman_container_status() {

    local container_name="${1}"
    eval "$(${podman_executable} inspect --type container "${container_name}" --format 'last_container_status={{.State.Status}};' 2>/dev/null)"
}

is_podman_user_socket_available() {

    local podman_socket="${XDG_RUNTIME_DIR-}/podman/podman.sock"

    # The socket has to exist...
    [ -S "${podman_socket}" ] || return 1

    # ... and it should be controlled by the systemd user session.
    systemctl status --user podman.socket >/dev/null
    return ${?}
}
