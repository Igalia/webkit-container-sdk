#!/usr/bin/env bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }

# Internal helpers
_get_sdk_images_directory() { echo "${WKDEV_SDK}/images"; }

# Get absolute path to '<wkdev-sdk>/images/<image>' directory, given an image name.
# The subdirectory name is equal to the image name, except that hyphens transform to
# underscores (image name: wkdev-sdk -> directory name: wkdev_sdk).
get_image_directory_by_name() {

    local image_name="${1}"
    local image_directory="$(_get_sdk_images_directory)/${image_name//-/_}"
    [ ! -d "${image_directory}" ] && _abort_ "Invalid image directory '${image_directory}' for image name '${image_name}'"
    echo "${image_directory}"
}
