#!/usr/bin/bash

application_path=${0}
application_name=$(basename ${application_path})
application_directory=$(cd "$(dirname "${application_path:-$PWD}")" 2>/dev/null 1>&2 && pwd)
printf "${application_name}: Listingg podman4 related package information.\n"

trap '[ "$?" -ne 0 ] && printf "[ERROR] A fatal error occurred. Aborting!\n"' EXIT

alvistack_repository="https://download.opensuse.org/repositories/home:/alvistack/xUbuntu_22.10"

set -o errexit # Exit upon command failure
set -o nounset # Warn about unset variables

# 1) Switch to temporary directory
temporary_directory=$(mktemp -d)
pushd ${temporary_directory} &>/dev/null
printf "\n-> Switched into temporary working directory '${temporary_directory}'.\n"

# 2) Scan alvistack repository for dsc files
printf "\n-> Listing Alvistack repository (${alvistack_repository}), containing recent podman related dsc files...\n"
curl --silent --location --output remote_listing https://download.opensuse.org/repositories/home:/alvistack/xUbuntu_22.10

# 3) Retrieve podman related dsc files
search_packages=(golang-1.20 crun containers-common containers-storage catatonit conmon containernetworking containernetworking-plugins buildah skopeo libslirp slirp4netns podman podman-netavark)

printf "\n-> Looking up podman related packages...\n"
dsc_urls=()
for package_name in "${search_packages[@]}"; do
    printf "\n    -> Search for package '${package_name}'...\n"

    # Temporarilty disable: Exit upon command failure
    set +o errexit

    xmllint --html --xpath "//td[contains(@class, 'name')]/a[starts-with(@href, './${package_name}_') and contains(@href, '-1.dsc')]/text()" ./remote_listing 2>remote_listing.stderr 1>remote_listing.stdout
    status=${?}
    if [ ${status} -ne 0 ]; then
        echo "Error log:"
        cat remote_listing.stderr
        exit ${status}
    fi

    set -o errexit

    dsc_file=$(cat remote_listing.stdout | sort -u | tail -n 1)
    dsc_url="${alvistack_repository}/${dsc_file}"
    dsc_urls+=(${dsc_url})

    if [ -z "${dsc_file}" ]; then
        printf "       Did not find a result. Error log:\n"
        cat remote_listing.log
        exit 1
    else
        printf "       Found: ${dsc_url}\n"
    fi
done

# 4) List results
printf "\n-> Gathered package information. Listing results:\n"

dsc_index=0
for dsc_url in "${dsc_urls[@]}"; do
    package_name=${search_packages[${dsc_index}]}
    dsc_index=$((dsc_index+1))

    printf "\n   -> Package name:  ${package_name}"
    printf "\n      Package desc.: $(apt-cache search ${package_name} | grep \^${package_name}\ )"
    printf "\n      Package URL:   ${dsc_url}"
    printf "\n      Build deps.:   $(curl --silent "${dsc_url}" | grep Build-Depends)\n"
done
