#!/bin/bash
# This script is intended to run on the container.
# It will do the following:
# 1. Install system *-dev packages needed for the libraries of the jhbuild
# 2. Download and install jhbuild
# 3. Build and install all the modules defined on jhbuildrc
# 4. Clean everything (delete sources and intermediate built products)
set -eux -o pipefail
THISDIR="$(dirname $(readlink -f ${0}))"
cd "${THISDIR}"

# Install system libraries and tools for building the jhbuild
export DEBIAN_FRONTEND="noninteractive"
# Enable apt-src entries
sed -i '/deb-src/s/^# //' /etc/apt/sources.list
apt update

# All apt build-deps for building this packages will be installed (but not the package itself)
APT_PACKAGES_INSTALL_BUILDEPS="\
	gst-libav1.0 \
	gst-plugins-bad1.0 \
	gst-plugins-base1.0 \
	gst-plugins-good1.0 \
	gst-plugins-ugly1.0 \
"
apt -y build-dep  ${APT_PACKAGES_INSTALL_BUILDEPS}

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
apt install -y ${APT_DEPSTOINSTALL}

# system-wide installation
export JHBUILD_RUN_AS_ROOT=1

# Get jhbuild
git clone https://gitlab.gnome.org/GNOME/jhbuild.git
cd jhbuild
./autogen.sh --prefix=/usr/local
make
make install

# Build and install the moduleset
/usr/local/bin/jhbuild -f "${THISDIR}/jhbuildrc" -m "${THISDIR}/jhbuild.modules" build
