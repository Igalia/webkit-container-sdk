#!/usr/bin/bash

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

#####
##### Container registry
#####
# TODO: Switch to 'quay.io' registry, replacing 'docker.io'?
get_default_container_registry() { echo "docker.io"; }

# TODO: Transfer ownership from 'nikolaszimmermann' to 'igalia' account.
get_default_container_registry_user_name() { echo "nikolaszimmermann"; }

#####
##### Container naming/versioning
#####
# TODO: Enable proper versioning instead of always using 'latest'.
# (always require latest 'wkdev-sdk' Git checkout (ToT main branch) + arbitrary versioned images)
get_default_container_tag() { echo "latest"; }

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
get_sdk_image_tag() { get_default_container_tag; }
get_sdk_qualified_name() { get_qualified_name "$(get_sdk_image_name)"; }
get_sdk_qualified_name_and_tag() { get_qualified_name_and_tag "$(get_sdk_image_name)" "$(get_sdk_image_tag)"; }

##### wkdev-package-proxy definitions
get_package_proxy_image_name() { echo "wkdev-package-proxy"; }
get_package_proxy_image_tag() { get_default_container_tag; }
get_package_proxy_qualified_name() { get_qualified_name "$(get_package_proxy_image_name)"; }
get_package_proxy_qualified_name_and_tag() { get_qualified_name_and_tag "$(get_package_proxy_image_name)" "$(get_package_proxy_image_tag)"; }

##### wkdev-package-builder definitions
get_package_builder_image_name() { echo "wkdev-package-builder"; }
get_package_builder_image_tag() { get_default_container_tag; }
get_package_builder_qualified_name() { get_qualified_name "$(get_package_builder_image_name)"; }
get_package_builder_qualified_name_and_tag() { get_qualified_name_and_tag "$(get_package_builder_image_name)" "$(get_package_builder_image_tag)"; }

##### Custom built packages (build definitions)
get_custom_package_distribution() { echo "kinetic"; }
get_custom_package_component() { echo "main"; }
get_custom_package_local_apt_repository_name() { echo "wkdev-sdk-packages"; }
get_custom_package_local_apt_repository_source_list() { echo "/etc/apt/sources.list.d/$(get_custom_package_local_apt_repository_name).list"; }

# Corresponds to the list of .yaml files in 'images/wkdev_sdk/custom_built_packages'.
get_custom_package_build_definitions() { echo "wkdev-podman4-ubuntu-kinetic" "wkdev-webkit-dependencies"; }
