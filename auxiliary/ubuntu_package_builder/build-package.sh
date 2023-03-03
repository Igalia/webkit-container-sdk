#!/usr/bin/bash
trap '[ "$?" -ne 0 ] && printf "[ERROR] A fatal error occurred. Aborting!\n"' EXIT

build_profile=${1}
package_full_name=${2}
debuild_options=${3}

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

# Choose 'DEB_BUILD_OPTIONS' and 'debuild_options' according to build profile.
# Build profile: fast (do not generate documentation, do not run tests after build, do not run lintian -- used for _development_ (all packages built _in_ the container are built in 'fast' mode)
# Build profile: full (generate documentation, run tests after build, run lintian -- used for the self-compiled packages that got created during SDK image creation (all packages built on the host use 'full')
DEB_BUILD_OPTIONS_fast="nocheck nodoc"
DEB_BUILD_OPTIONS_full=""
DEB_BUILD_OPTIONS_selected=DEB_BUILD_OPTIONS_${build_profile}

use_debuild_options_fast="--no-lintian"
if [ ! -z "${debuild_options}" ]; then
    use_debuild_options_fast="${use_debuild_options_fast} ${debuild_options}"
fi
use_debuild_options_full="${debuild_options}"
use_debuild_options_selected=use_debuild_options_${build_profile}

if [ "${build_profile}" == "fast" ] || [ "${build_profile}" == "full" ]; then
    printf "\n-> Selected build profile '${build_profile}':\n"
    printf "   DEB_BUILD_OPTIONS=\"${!DEB_BUILD_OPTIONS_selected}\" -- passed as environment variable to 'gbp buildpackage'\"\n"
    printf "   debuild_options=\"${!use_debuild_options_selected}\" -- passed as aditional options to 'debuild'\n\n"
else
    printf "\n-> Unknown build profile '${build_profile}'. Please either pass 'fast' or 'full'.\n"
    exit 1
fi

DEB_BUILD_OPTIONS="${!DEB_BUILD_OPTIONS_selected}" gbp buildpackage \
    --git-builder="debuild ${!use_debuild_options_selected} --prepend-path='/usr/lib/ccache' --preserve-envvar='CCACHE_*' --no-sign" \
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
