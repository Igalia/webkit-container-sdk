#!/usr/bin/bash

trap '[ "$?" -ne 0 ] && printf "[ERROR] A fatal error occurred. Aborting!\n"' EXIT

package_full_name=${1}
debuild_options=${2}

package_name=$(basename "${package_full_name}")
work_directory="/builder/work"
packages_directory="${work_directory}/packages"
source_directory="${work_directory}/sources/${package_full_name}/${package_name}"
build_directory="${work_directory}/builds/${package_full_name}"
dependencies_file="${build_directory}/.dependencies"

set -o errexit # Exit upon command failure
set -o nounset # Warn about unset variables

source /builder/setup-container.sh

APT="eatmydata apt --assume-yes"
APT_GET="eatmydata apt-get --assume-yes"

# Update apt repositories
printf "\n-> Updating APT repositories (for dependency resolving)...\n"
${APT_GET} update

if [ -f "${dependencies_file}" ]; then
    # Parse dependencies file
    install_string=""
    while IFS= read -r line
    do
        if [ -z "${install_string}" ]; then
            install_string="${line}"
        else
            install_string="${install_string} ${line}"
        fi
    done < "${dependencies_file}"

    # Install additional dependencies
    if [ ! -z "${install_string}" ]; then
        printf "\n-> Installing packages specified in '${dependencies_file}'...\n"
        printf "  All additional packages to install: '${install_string}'\n"
        pushd "${packages_directory}" &>/dev/null
        sudo ${APT} install ${install_string}
        popd &>/dev/null
    fi
fi

# Print statistics
printf "\n-> ccache build cache statistics:\n"
ccache --show-stats --verbose | sed -e "s/^/    /"

printf "\n-> Switch into source directory '${source_directory}'.\n"
pushd "${source_directory}" &>/dev/null

# Install build dependencies, as specified in dsc file.
printf "\n-> Installing build dependencies using 'mk-build-deps'...\n"
mk-build-deps --install --remove --tool "${APT_GET} -o Debug::pkgProblemResolver=yes"

# Build package
printf "\n-> Building package using 'gbp buildpackage'...\n"
printf "   Build log location: ${build_directory}/build.log\n"

DEB_BUILD_OPTIONS=nocheck gbp buildpackage \
    --git-builder="debuild --prepend-path='/usr/lib/ccache' --preserve-envvar='CCACHE_*' --no-sign ${debuild_options}" \
    --git-export-dir="${build_directory}" --git-no-purge --git-ignore-branch --git-ignore-new --git-pristine-tar-commit &> "${build_directory}/build.log" &

build_pid=${!}
tail --follow --pid=${build_pid} "${build_directory}/build.log" &

wait ${build_pid}
build_status=${?}

if [ ${build_status} -ne 0 ]; then
    printf "\n-> Build failed. Aborting with exit code ${build_status}.\n"
fi

popd &>/dev/null

# Copy packages to final destination
printf "\n-> Copy build artifacts to packages directory '${packages_directory}'...\n"

pushd "${packages_directory}" &>/dev/null

file_extensions=(ddeb deb)
for file_extension in "${file_extensions[@]}"; do
    find ../builds/${package_full_name}/ -type f -name \*.${file_extension} -exec ln --symbolic --force --verbose {} "${packages_directory}"/ \;
done

popd &>/dev/null

printf "\n-> Finished!\n"
