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

# Get a label value from an existing container.
get_podman_container_label_value() {

    local container_name="${1}"
    local label_name="${2}"
    run_podman inspect --type container --format "{{with index .Config.Labels \"${label_name}\"}}{{.}}{{end}}" "${container_name}" 2>/dev/null
}

# Get the location where the home directory for a container is stored on the host.
get_podman_container_home_directory_on_host() {

    local container_name="${1}"

    local home_path
    home_path="$(get_podman_container_label_value "${container_name}" "wkdev.home-path")"
    if [ -n "${home_path}" ]; then
        echo "${home_path}"
        return 0
    fi

    # Fallback for legacy containers created before labels were introduced.
    run_podman inspect --type container --format "{{range .Config.Env}}{{println .}}{{end}}" "${container_name}" 2>/dev/null \
        | grep '^HOST_CONTAINER_HOME_PATH=' \
        | sed -e 's/^HOST_CONTAINER_HOME_PATH=//' \
        | head --lines 1
}

get_podman_container_shared_directory_on_host() {

    get_podman_container_label_value "${1}" "wkdev.shared-dir-path"
}

# Get most recent known image ID given an image name.
get_image_id_by_image_name() {

    local image_name="${1}"
    run_podman inspect --type image --format "{{.Id}}" "${image_name}" 2>/dev/null
}

# Filters a raw OCI version label value, returning it only when it matches our
# <major>.<minor>-v<count>[-<gitsha>] scheme. Legacy images inherit an
# `org.opencontainers.image.version` from their Ubuntu base (e.g. "24.04") which
# would otherwise be misclassified as a wkdev-sdk version by version-comparison logic.
filter_version_label() {

    local raw="${1-}"
    [[ "${raw}" =~ ${WKDEV_SDK_VERSION_RE} ]] && echo "${raw}"
}

# Issues a single `podman inspect` to retrieve the image name, image ID and
# OCI version label of a container in one call. Echoes "<image_name>|<image_id>|<raw_version>".
get_container_inspect_summary() {

    local container_name="${1}"
    run_podman inspect --type container \
        --format '{{.ImageName}}|{{.Image}}|{{with index .Config.Labels "org.opencontainers.image.version"}}{{.}}{{end}}' \
        "${container_name}" 2>/dev/null
}

# Get list of all containers by name.
get_list_of_containers() { run_podman container list --all --format "{{.Names}}"; }

# Lists wkdev-sdk versions present in the registry, sorted ascending (`sort -V`).
# Optional second argument restricts the listing to versions whose <major>.<minor>
# prefix matches (e.g. "2.53" -> all "2.53-v<count>-<gitsha>" tags).
list_available_sdk_versions() {

    local image_qualified="${1}"
    local prefix="${2-}"
    local pattern="${WKDEV_SDK_VERSION_RE}"
    if [ -n "${prefix}" ]; then
        local prefix_re="${prefix//./\\.}"
        pattern="^${prefix_re}-v[0-9]+-[0-9a-f]+\$"
    fi
    run_podman search --list-tags --format '{{.Tag}}' "${image_qualified}" 2>/dev/null \
        | grep -E "${pattern}" | sort -V
}
