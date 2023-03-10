#!/usr/bin/bash

application_path=${0}
application_name=$(basename ${application_path})
application_directory=$(cd "$(dirname "${application_path:-$PWD}")" 2>/dev/null 1>&2 && pwd)
printf "${application_name}: Build wkdev-package-proxy image.\n\n"

# Prevent to run this script from the container
if [ -f /run/.containerenv ]; then
    printf "The script '${application_name}' is not intended to run from within the container.\n"
    exit 1
fi

# Verify pre-requisite: podman needs to be installed.
if ! command -v podman > /dev/null; then
    printf "Cannot find podman executable.\n"
    exit 1
fi

# Bash scripting recommendations
set -o errexit # Exit upon command failure
set -o nounset # Warn about unset variables

printf "\n-> Building image...\n"

pushd "${application_directory}" &>/dev/null
podman build --jobs $(nproc --ignore=2) --tag docker.io/nikolaszimmermann/wkdev-package-proxy:22.10 ${@} .
popd &>/dev/null

printf "\n-> Finished building image!\n"
