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
get_default_container_registry() { echo "${WKDEV_SDK_CONTAINER_REGISTRY:-ghcr.io}"; }
get_default_container_registry_user_name() { echo "${WKDEV_SDK_CONTAINER_REGISTRY_USER_NAME:-igalia}"; }

#####
##### Container naming/versioning
#####
get_default_container_tag() {
    local default='latest'

    if [[ "$(git -C "${WKDEV_SDK}" rev-parse --abbrev-ref HEAD)" =~ tag/(.*) ]]; then
        default="${BASH_REMATCH[1]}" 
    fi

    echo "${WKDEV_SDK_TAG:-"${default}"}";
}

# Given an image name, return the qualified image name "<registry>/<registry-user-name>/<image-name>"
get_qualified_name() {

    local image_name="${1}"
    echo "$(get_default_container_registry)/$(get_default_container_registry_user_name)/${image_name}"
}


# Get absolute path to 'user_home_directory_defaults' directory in the wkdev-sdk.
get_container_home_defaults_directory_name() { echo "${WKDEV_SDK}/images/wkdev_sdk/user_home_directory_defaults"; }

##### wkdev-sdk definitions
get_sdk_image_name() { echo "wkdev-sdk"; }
get_sdk_qualified_name() { get_qualified_name "$(get_sdk_image_name)"; }
