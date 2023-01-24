#!/usr/bin/bash
WORKDIR=/tmp/wkdev-deps
#rm -Rf ${WORKDIR} &>/dev/null

log_error() {
    echo "[ERROR] ${1}"
}

check_exit_code() {
    if [[ ${?} -ne 0 ]]; then
        log_error "${1}"
        exit 1
    fi
}

check_exit_code_and_popd() {
    if [[ ${?} -ne 0 ]]; then
        log_error "${1}"
        popd &> /dev/null
        exit 1
    fi
}

PACKAGE=${1}
if [[ "${PACKAGE}" == "" ]]; then
    log_error "You have to specify a package as command line argument. Aborting!"
    exit 1
fi

# Try to enter the work directory, abort early if that fails.
mkdir -p "${WORKDIR}" &> /dev/null
check_exit_code "Failed to create work directory \"${WORKDIR}\". Aborting!"

pushd "${WORKDIR}" &>/dev/null
check_exit_code_and_popd "Failed to change to work directory \"${WORKDIR}\". Aborting!"

# 1) Install build dependencies.
sudo apt-get build-dep --assume-yes "${PACKAGE}"
check_exit_code_and_popd "\"apt-get --build source ${PACKAGE}\" failed. Aborting!"

# 2) Download source package.
apt-get --download-only source "${PACKAGE}"
check_exit_code_and_popd "\"apt-get --download-only source ${PACKAGE}\" failed. Aborting!"

# 3) Extract source package.
dpkg-source --extract "${PACKAGE}"_*.dsc
check_exit_code_and_popd "\"dpkg-source -x ${PACKAGE}_*.dsc\" failed. Aborting!"

# 4) Apply custom patches, if necessary.
PATCHES_DIRECTORY="${WKDEV_SDK}/packages/sources/custom/${PACKAGE}/patches"
if [[ -d "${PATCHES_DIRECTORY}" ]]; then
    PATCHES=$(find "${PATCHES_DIRECTORY}/" -type f -name "*.patch" | sort -n)
    for PATCH in "${PATCHES}"; do
        patch -p0 < "${PATCH}"
        check_exit_code_and_popd "Failed to apply patch \"${PATCH}\". Aborting!"
    done
fi

# 5) Build source package.
pushd "${PACKAGE}"-*
# &>/dev/null
check_exit_code_and_popd "Failed to change to source directory \"${WORKDIR}/${PACKAGE}_*\". Aborting!"

dpkg-buildpackage --root-command=fakeroot --unsigned-changes --build=binary --jobs=auto
check_exit_code_and_popd "Failed to build debian binary package. Aborting!"
popd &> /dev/null

popd &> /dev/null

echo ""
echo "Finished"
