#!/usr/bin/bash

build_profile=${1}
package_full_name=${2}
deb_build_options=${3}
dpkg_buildpackage_options=${4}

package_name=$(basename "${package_full_name}")
work_directory="/builder/work"
packages_directory="/builder/packages"
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

printf "\n-> Switch into source directory '${source_directory}', preparing to build '${package_name}'...\n"
pushd "${source_directory}" &>/dev/null

# Install build dependencies, as specified in dsc file.
printf "\n-> Installing build dependencies using 'mk-build-deps'...\n"
mk-build-deps --install --remove --tool "${APT_GET} -o Debug::pkgProblemResolver=yes"

# Build package
printf "\n-> Building package using 'gbp buildpackage'...\n"
printf "   Build log location: ${build_directory}/build.log\n"

# Choose 'DEB_BUILD_OPTIONS' and 'DEBUILD_LINTIAN' environment variable values according to build profile.
# Build profile: fast -> do not generate documentation, do not run tests after build, do not run lintian -- used for _development_ (all packages built _in_ the container are built in 'fast' mode)
# Build profile: full -> generate documentation, run tests after build, run lintian -- used for the self-compiled packages that got created during SDK image creation (all packages built on the host use 'full')
DEB_BUILD_OPTIONS_fast="nocheck nodoc"
DEB_BUILD_OPTIONS_full=""
if [ ! -z "${deb_build_options}" ]; then
    DEB_BUILD_OPTIONS_selected=deb_build_options
else
    DEB_BUILD_OPTIONS_selected=DEB_BUILD_OPTIONS_${build_profile}
fi

DEBUILD_LINTIAN_fast="no"
DEBUILD_LINTIAN_full="yes"
DEBUILD_LINTIAN_selected=DEBUILD_LINTIAN_${build_profile}

if [ "${build_profile}" == "fast" ] || [ "${build_profile}" == "full" ]; then
    printf "\n-> Selected build profile '${build_profile}':\n"
    printf "   DEB_BUILD_OPTIONS=\"${!DEB_BUILD_OPTIONS_selected}\" -- passed as environment variable to 'gbp buildpackage'\"\n"
    printf "   DEBUILD_LINTIAN=\"${!DEBUILD_LINTIAN_selected}\" -- passed as environment variable to 'gbp buildpackage'\"\n"
else
    printf "\n-> Unknown build profile '${build_profile}'. Please either pass 'fast' or 'full'.\n"
    exit 1
fi

DEBUILD_LINTIAN="${!DEBUILD_LINTIAN_selected}" DEB_BUILD_OPTIONS="${!DEB_BUILD_OPTIONS_selected}" gbp buildpackage \
    --git-builder="debuild --prepend-path='/usr/lib/ccache' --preserve-envvar='CCACHE_*' --no-sign ${dpkg_buildpackage_options}" \
    --git-export-dir="${build_directory}" --git-no-purge --git-ignore-branch --git-ignore-new

popd &>/dev/null

file_extensions=(ddeb deb)
for file_extension in "${file_extensions[@]}"; do
    printf "\n-> Copy *.${file_extension} files from build directory '${build_directory}' to packages directory '${packages_directory}'...\n"
    find "${build_directory}"/  -type f -name "*.${file_extension}" -exec cp --archive --verbose {} "${packages_directory}"/ \;
done

printf "\n-> Finished!\n"
