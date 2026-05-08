#!/usr/bin/env bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }

##### SDK maintainer information
get_sdk_maintainer_name() { echo "Igalia"; }
get_sdk_maintainer_email() { echo "webkit-gtk@lists.webkit.org"; }

#####
##### Host/container environment detection
#####
get_init_done_file() { echo "/run/.wkdev-init-done"; }
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

# Single source of truth for the SDK version scheme, shared by every bash tool
# that needs to validate or filter version strings.
#   _RE              accepts the canonical form <major>.<minor>-v<count>[-<gitsha>]
#                    (sha optional, matching the bumped-but-unpublished Containerfile state).
#   _PUBLISHED_RE    accepts only fully-stamped <major>.<minor>-v<count>-<gitsha>
#                    (every image actually published to the registry has a sha).
#   _MAJOR_MINOR_RE  accepts the bare <major>.<minor> branch prefix.
readonly WKDEV_SDK_VERSION_RE='^[0-9]+\.[0-9]+-v[0-9]+(-[0-9a-f]+)?$'
readonly WKDEV_SDK_VERSION_PUBLISHED_RE='^[0-9]+\.[0-9]+-v[0-9]+-[0-9a-f]+$'
readonly WKDEV_SDK_MAJOR_MINOR_RE='^[0-9]+\.[0-9]+$'

# Read from /etc/wkdev-sdk-version inside the container, ARG WKDEV_SDK_VERSION in the
# Containerfile on the host. Intentionally no env-var/CLI override: every image used by
# wkdev-sdk tooling is the version pinned in this checkout.
get_sdk_version() {
    if is_running_in_wkdev_sdk_container && [ -r /etc/wkdev-sdk-version ]; then
        printf '%s\n' "$(</etc/wkdev-sdk-version)"
        return
    fi

    "${WKDEV_SDK}/scripts/helpers/print-sdk-version" || _abort_ "Cannot determine SDK version (see error above)."
}

# The container tag matches the SDK version - no override possible by design.
get_default_container_tag() { get_sdk_version; }

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
