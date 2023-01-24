FROM ubuntu:22.10

LABEL com.github.containers.toolbox="true"
LABEL maintainer="webkit-gtk@lists.webkit.org"
LABEL version="0.1"
LABEL description="Provides a complete WebKit Gtk/WPE development environment based on Ubuntu 22.10"

# Container environment hardcoded settings
ENV TERM linux
ENV LANG C.UTF-8
ARG NUMBER_OF_PARALLEL_BUILDS=4
ARG APT_UPDATE="apt-get update"
ARG APT_UPGRADE="apt-get upgrade -y"
ARG APT_INSTALL="apt-get install -y --no-install-recommends"
ARG APT_CLEANUP="apt-get -y autoremove && apt-get -y clean && rm -rf /var/lib/apt/lists/*"

# Disable prompt during package configuration
ENV DEBIAN_FRONTEND noninteractive

# NOTE: All RUN commands contain the (autoremove / clean / rm step to ensure that no intermediate layer
#       ever contains unncessary stuff that never appears in the final image, only in deeper layers, and
#       thus increases the whole image size no gain, except an "easier to read" Dockerfile.

# Enable source packages
RUN sed -i -e "s/^# deb-src/deb-src/" /etc/apt/sources.list

# Upgrade to latest Ubuntu revision
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} apt-utils dialog libterm-readline-gnu-perl && \
    ${APT_UPGRADE} && \
    ${APT_CLEANUP}

# Install and configure locale support (use 'en_US.UTF-8' as fixed locale).
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} locales && \
    localedef --inputfile=en_US --force --charmap=UTF-8 --alias-file=/usr/share/locale/locale.alias en_US.UTF-8 && \
    ${APT_CLEANUP}

# Switch to newly installed en_US.UTF-8 locale.
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

# Bootstrapping is done, switch to working directory /tmp to continue setup.
WORKDIR /tmp

# Install package groups in defined order.
COPY /packages/01-base.lst .
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} $(sed -e "s/.*#.*//; /^$/d" 01-base.lst) && \
    ${APT_CLEANUP}

COPY /packages/02-gcc.lst .
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} $(sed -e "s/.*#.*//; /^$/d" 02-gcc.lst) && \
    ${APT_CLEANUP}

COPY /packages/03-custom-stack-dependencies.lst .
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} $(sed -e "s/.*#.*//; /^$/d" 03-custom-stack-dependencies.lst) && \
    ${APT_CLEANUP}

COPY /packages/04-devtools.lst .
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} $(sed -e "s/.*#.*//; /^$/d" 04-devtools.lst) && \
    ${APT_CLEANUP}

# Cleanup and perform closure check (the whole block should do nothing)
RUN ${APT_UPDATE} && \
    ${APT_UPGRADE} && \
    ${APT_CLEANUP}

# Install WebKitGtk/WPE dependencies
RUN ${APT_UPDATE} && \
    git clone --filter=blob:none --no-checkout --depth=1 https://github.com/WebKit/WebKit.git && \
    cd WebKit && \
    git sparse-checkout set Tools/ && \
    git checkout main && \
    yes | ./Tools/gtk/install-dependencies && \
    yes | ./Tools/wpe/install-dependencies && \
    cd .. && \
    rm -rf WebKit && \
    ${APT_CLEANUP}

# FIXME: Uninstalls important packages such as libunwind-dev, breaking other things.
# COPY /packages/05-llvm.lst .
# RUN ${APT_UPDATE} && ${APT_INSTALL} $(sed -e "s/.*#.*//; /^$/d" 05-llvm.lst) && apt-get -y autoremove
#     apt-get -y autoremove && \
#     apt-get -y clean && \
#     rm -rf /var/lib/apt/lists/*

# Install python packages
RUN python3 -m pip install --upgrade pip && \
    pip3 install hotdoc

# Install fonts needed for running WebKit layout tests
RUN git clone https://github.com/WebKitGTK/webkitgtk-test-fonts.git && \
    make -C webkitgtk-test-fonts DESTDIR="/usr/share" install && \
    rm -rf webkitgtk-test-fonts

# Build & install JPEGXL
RUN git clone --recursive --shallow-submodules https://github.com/libjxl/libjxl.git && \
    cd libjxl && \
    git checkout v0.7.0 && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_TESTING=OFF \
    -DJPEGXL_ENABLE_FUZZERS=OFF \
    -DJPEGXL_ENABLE_DEVTOOLS=OFF \
    -DJPEGXL_ENABLE_TOOLS=OFF \
    -DJPEGXL_ENABLE_DOXYGEN=TRUE \
    -DJPEGXL_ENABLE_MANPAGES=OFF \
    -DJPEGXL_ENABLE_BENCHMARK=OFF \
    -DJPEGXL_ENABLE_EXAMPLES=OFF \
    -DJPEGXL_BUNDLE_LIBPNG=OFF \
    -DJPEGXL_ENABLE_JNI=OFF \
    -DJPEGXL_ENABLE_SJPEG=OFF \
    -DJPEGXL_ENABLE_OPENEXR=ON \
    -DJPEGXL_ENABLE_SKCMS=ON \
    -DJPEGXL_ENABLE_VIEWERS=OFF \
    -DJPEGXL_ENABLE_TCMALLOC=OFF \
    -DJPEGXL_ENABLE_PLUGINS=OFF \
    -DJPEGXL_ENABLE_COVERAGE=OFF \
    -DJPEGXL_ENABLE_PROFILER=OFF \
    -DJPEGXL_ENABLE_SIZELESS_VECTORS=OFF \
    -DJPEGXL_ENABLE_TRANSCODE_JPEG=OFF \
    -DJPEGXL_STATIC=OFF \
    -DJPEGXL_WARNINGS_AS_ERRORS=OFF \
    -DJPEGXL_FORCE_NEON=OFF\
    -DJPEGXL_FORCE_SYSTEM_BROTLI=ON \
    -DJPEGXL_FORCE_SYSTEM_GTEST=ON \
    -DJPEGXL_FORCE_SYSTEM_LCMS2=ON \
    -DJPEGXL_FORCE_SYSTEM_HWY=OFF .. && \
    cmake --build . -- -j${NUMBER_OF_PARALLEL_BUILDS} && \
    cmake --install . && \
    cd .. && \
    rm -rf build

# Install recent valgrind (build & install 3.20 from Git)

# The Ubuntu 22.10 included valgrind 3.18 fails to parse the DWARF information
# from WebKit builds, leading to following error message:
#
# $ valgrind --leak-check=full --show-leak-kinds=all WebKitBuild/Debug/bin/MiniBrowser
# ==90449== Memcheck, a memory error detector
# ==90449== Copyright (C) 2002-2017, and GNU GPL'd, by Julian Seward et al.
# ==90449== Using Valgrind-3.18.1 and LibVEX; rerun with -h for copyright info
# ==90449== Command: WebKitBuild/Debug/bin/MiniBrowser --read-inline-info=no --read-var-info=no --allow-mismatched-debuginfo=yes --keep-debuginfo=yes --help
# ==90449==
# ==90449== Valgrind: debuginfo reader: ensure_valid failed:
# ==90449== Valgrind:   during call to ML_(img_get_UChar)
# ==90449== Valgrind:   request for range [324009, +1) exceeds
# ==90449== Valgrind:   valid image size of 324008 for image:
# ==90449== Valgrind:   "/home/nzimmermann/Software/GitRepositories/WebKit/WebKitBuild/Debug/bin/MiniBrowser"
# ==90449==
# ==90449== Valgrind: debuginfo reader: Possibly corrupted debuginfo file.
# ==90449== Valgrind: I can't recover.  Giving up.  Sorry.
#
# valgrind > 3.18 includes fixes related to parsing DWARF5 information, attempting
# to fix debuginfo reading for binaries built using clang >= 14, where DWARF5 is
# enabled by default. As side-effect it also fixes the issue we have, so let's
# just switch to valgrind 3.20 and move on.
RUN git clone git://sourceware.org/git/valgrind.git && \
    cd valgrind && \
    git checkout VALGRIND_3_20_0 && \
    ./autogen.sh && \
    ./configure --prefix=/usr && \
    make -j${NUMBER_OF_PARALLEL_BUILDS} && \
    make install

# Switch back to interactive prompt, when using apt.
ENV DEBIAN_FRONTEND dialog

# Keep snapshot of wkdev-sdk in container image
COPY . /wkdev-sdk
