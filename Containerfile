FROM ubuntu:22.10

LABEL com.github.containers.toolbox="true"
LABEL maintainer="webkit-gtk@lists.webkit.org"
LABEL version="0.1"
LABEL description="Provides a complete WebKit Gtk/WPE development environment based on Ubuntu 22.10"

# Container environment hardcoded settings
ENV TERM linux
ENV LANG C.UTF-8
ARG NUMBER_OF_PARALLEL_BUILDS=4

# Disable prompt during package configuration
ENV DEBIAN_FRONTEND noninteractive

# NOTE: All RUN commands contain the (autoremove / clean / rm step to ensure that no intermediate layer
#       ever contains unncessary stuff that never appears in the final image, only in deeper layers, and
#       thus increases the whole image size no gain, except an "easier to read" Dockerfile.

# Upgrade to latest Ubuntu revision
RUN apt-get update && \
    apt-get -y install apt-utils dialog libterm-readline-gnu-perl && \
    apt-get -y upgrade && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

# Install and configure locale support (use 'en_US.UTF-8' as fixed locale).
RUN apt-get update && \
    apt-get -y install locales && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

# Switch to newly installed en_US.UTF-8 locale.
ENV LANG en_US.UTF-8

# Bootstrapping is done, switch to working directory /tmp to continue setup.
WORKDIR /tmp

# Install package groups in defined order.
COPY /packages/01-base.lst .
RUN apt-get update && \
    apt-get -y install $(sed -e "s/.*#.*//; /^$/d" 01-base.lst) && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

COPY /packages/02-gcc.lst .
RUN apt-get update && \
    apt-get -y install $(sed -e "s/.*#.*//; /^$/d" 02-gcc.lst) && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

COPY /packages/03-custom-stack-dependencies.lst .
RUN apt-get update && \
    apt-get -y install $(sed -e "s/.*#.*//; /^$/d" 03-custom-stack-dependencies.lst) && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

COPY /packages/04-devtools.lst .
RUN apt-get update && \
    apt-get -y install $(sed -e "s/.*#.*//; /^$/d" 04-devtools.lst) && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

# Cleanup and perform closure check (the whole block should do nothing)
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

# Install WebKitGtk/WPE dependencies
RUN apt-get update && \
    git clone --filter=blob:none --no-checkout --depth=1 https://github.com/WebKit/WebKit.git && \
    cd WebKit && \
    git sparse-checkout set Tools/ && \
    git checkout main && \
    yes | ./Tools/gtk/install-dependencies && \
    yes | ./Tools/wpe/install-dependencies && \
    cd .. && \
    rm -rf WebKit && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

# FIXME: Uninstalls important packages such as libunwind-dev, breaking other things.
# COPY /packages/05-llvm.lst .
# RUN apt-get update && apt-get -y install $(sed -e "s/.*#.*//; /^$/d" 05-llvm.lst) && apt-get -y autoremove
#     apt-get -y autoremove && \
#     apt-get -y clean && \
#     rm -rf /var/lib/apt/lists/*

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

# Switch back to interactive prompt, when using apt.
ENV DEBIAN_FRONTEND dialog
