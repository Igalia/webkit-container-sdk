#!/usr/bin/env bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }

##### SDK maintainer information
get_sdk_maintainer_name() { echo "Igalia"; }
get_sdk_maintainer_email() { echo "webkit-gtk@lists.webkit.org"; }

#####
##### Host/container environment detection
#####
get_init_done_file() { echo "/run/.wkdev-init-done"; }
is_first_time_run() { [ ! -f "$(get_init_done_file)" ]; }
is_running_in_container() { [ -f "/run/.containerenv" ]; }
is_running_in_wkdev_sdk_container() { is_running_in_container && [ -f "/usr/bin/podman-host" ]; }

#####
##### Container registry
#####
get_default_container_registry() { echo "${WKDEV_SDK_CONTAINER_REGISTRY:-gitlab.igalia.com:4567}"; }
get_default_container_registry_user_name() { echo "${WKDEV_SDK_CONTAINER_REGISTRY_USER_NAME:-teams/webkit/wkdev-sdk}"; }

#####
##### Container naming/versioning
#####
get_container_tag() { echo "${WKDEV_SDK_TAG:-latest}"; }

# Given an image name, return the qualified image name "<registry>/<registry-user-name>/<image-name>"
get_qualified_name() {

    local image_name="${1}"
    echo "$(get_default_container_registry)/$(get_default_container_registry_user_name)/${image_name}"
}

# Given an image name, return the tagged, qualified image name "<registry>/<registry-user-name>/<image-name>:<image-tag>"
get_qualified_name_and_tag() {

    local image_name="${1}"
    local image_tag="${2}"
    echo "$(get_qualified_name "${image_name}"):${image_tag}"
}

# Get absolute path to 'user_home_directory_defaults' directory in the wkdev-sdk.
get_container_home_defaults_directory_name() { echo "${WKDEV_SDK}/images/wkdev_sdk/user_home_directory_defaults"; }

##### wkdev-sdk definitions
get_sdk_image_name() { echo "wkdev-sdk"; }
get_sdk_image_tag() { get_container_tag; }
get_sdk_qualified_name_and_tag() { get_qualified_name_and_tag "$(get_sdk_image_name)" "$(get_sdk_image_tag)"; }

##### ci-runner definitions
get_ci_runner_image_name() { echo "ci-runner"; }
get_ci_runner_image_tag() { echo "latest"; }
get_ci_runner_qualified_name_and_tag() { get_qualified_name_and_tag "$(get_sdk_image_name)" "$(get_sdk_image_tag)"; }