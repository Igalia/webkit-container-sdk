#!/usr/bin/env bash
# This script is intended to run on the container.
# It will do the following:
# 1. Install system *-dev packages needed for the libraries of the jhbuild
# 2. Download and install jhbuild
# 3. Build and install all the modules defined on jhbuildrc
#
set -eux -o pipefail
# Note: this script doesn't source other scripts (or use resources) from
# other directories than its own main top-level directory on purpose
# This is because when the container is created in the Containerfile
# definition this folder is copied into a temporal directory and this
# script is executed. It doesn't have access to files outside of its
# own directory at run-time
THISDIR="$(dirname $(readlink -f ${0}))"
cd "${THISDIR}"

# Install system libraries and tools for building the jhbuild
export DEBIAN_FRONTEND="noninteractive"
# Enable apt-src entries
sed -i '/deb-src/s/^# //' /etc/apt/sources.list
apt-get update

# All apt build-deps for building this packages will be installed (but not the package itself)
APT_PACKAGES_INSTALL_BUILDEPS="\
	gst-libav1.0 \
	gst-plugins-bad1.0 \
	gst-plugins-base1.0 \
	gst-plugins-good1.0 \
	gst-plugins-ugly1.0 \
"
apt-get --assume-yes build-dep  ${APT_PACKAGES_INSTALL_BUILDEPS}

# Install extra system deps manually specified
APT_GSTREAMERDEPS="\
	liborc-0.4-dev \
	libsrtp2-dev \
	"
APT_SYSTEMDEPS="\
	cmake \
	ninja-build\
	"
APT_DEPSTOINSTALL="\
	${APT_GSTREAMERDEPS} \
	${APT_SYSTEMDEPS} \
	"
apt-get --assume-yes install ${APT_DEPSTOINSTALL}

# Do the initial install as root, later will chown the jhbuild dirs to the user uid at wkdev-create time
export JHBUILD_RUN_AS_ROOT=1

# Get jhbuild and install it system-wide
git clone https://gitlab.gnome.org/GNOME/jhbuild.git
cd jhbuild
./autogen.sh --prefix=/usr/local
make
make install

# Build and install the moduleset
export JHBUILDRC="${THISDIR}/jhbuildrc"
exec /usr/local/bin/jhbuild build
