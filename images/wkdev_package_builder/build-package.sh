#!/usr/bin/env bash

# NOTE: This runs in a container where the wkdev-sdk is not available, therefore
# we're not making use of the standard "init_application" logic.
#
# In contrary to all other scripts this one also uses "set -o errexit" by default.

build_profile="${1}"
package_full_name="${2}"
deb_build_options="${3}"

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
export DEBIAN_FRONTEND=noninteractive

# Update apt repositories
echo ""
echo "-> Updating APT repositories (for dependency resolving)..."
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
        echo ""
        echo "-> Installing packages specified in '${dependencies_file}'..."
        echo "  All additional packages to install: '${install_string}'"
        pushd "${packages_directory}" &>/dev/null
        sudo ${APT} install ${install_string}
        popd &>/dev/null
    fi
fi

# Print statistics
echo ""
echo "-> ccache build cache statistics:"
ccache --show-stats --verbose | sed -e "s/^/    /"

echo ""
echo "-> Switch into source directory '${source_directory}', preparing to build '${package_name}'..."
pushd "${source_directory}" &>/dev/null

# Install build dependencies, as specified in dsc file.
echo ""
echo "-> Installing build dependencies using 'mk-build-deps'..."
mk-build-deps --install --remove --tool "${APT_GET} -o Debug::pkgProblemResolver=yes"

# Build package
echo ""
echo "-> Building package using 'gbp buildpackage'..."

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
    echo ""
    echo "-> Selected build profile '${build_profile}':"
    echo "   deb_build_options=\"${deb_build_options}\" -- if set, overrides DEB_BUILD_OPTIONS.\""
    echo "   DEB_BUILD_OPTIONS=\"${!DEB_BUILD_OPTIONS_selected}\" -- passed as environment variable to 'gbp buildpackage'\""
    echo "   DEBUILD_LINTIAN=\"${!DEBUILD_LINTIAN_selected}\" -- passed as environment variable to 'gbp buildpackage'\""
else
    echo ""
    echo "-> Unknown build profile '${build_profile}'. Please either pass 'fast' or 'full'."
    exit 1
fi

export DEBUILD_LINTIAN="${!DEBUILD_LINTIAN_selected}"
export DEB_BUILD_OPTIONS="${!DEB_BUILD_OPTIONS_selected}"
export GBP_CONF_FILES="${build_directory}/gbp.conf"
gbp buildpackage

popd &>/dev/null

file_extensions=(ddeb deb)
for file_extension in "${file_extensions[@]}"; do
    echo ""
    echo "-> Copy *.${file_extension} files from build directory '${build_directory}' to packages directory '${packages_directory}'..."
    find "${build_directory}"/  -type f -name "*.${file_extension}" -exec cp --archive --verbose {} "${packages_directory}"/ \;
done

echo ""
echo "-> Finished!"
