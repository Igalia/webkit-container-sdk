FROM ubuntu:22.10

LABEL maintainer="webkit-gtk@lists.webkit.org"
LABEL version="0.1"
LABEL description="Provides a complete WebKit Gtk/WPE development environment based on Ubuntu 22.10"

# Tweakable "make -j <x>" setting.
ARG NUMBER_OF_PARALLEL_BUILDS=4
ARG CONTAINER_LOCALE=en_US.UTF-8

# No need to modify these.
ARG APT_UPDATE="apt-get update"
ARG APT_UPGRADE="apt-get --assume-yes upgrade"
ARG APT_INSTALL="apt-get --assume-yes install --no-install-recommends"
ARG APT_AUTOREMOVE="apt-get --assume-yes autoremove"
ARG APT_CLEAN="apt-get --assume-yes clean"
ARG APT_DELETE_LISTS="rm -rf /var/lib/apt/lists/*"

# Disable prompt during package configuration
ENV DEBIAN_FRONTEND noninteractive

# NOTE: All RUN commands contain the (autoremove / clean / rm step to ensure that no intermediate layer
#       ever contains unncessary stuff that never appears in the final image, only in deeper layers, and
#       thus increases the whole image size no gain, except an "easier to read" Dockerfile.

# Disable sandboxing (dropping privileges to _apt user during apt-get update/install/... fails when using
# podman in podman if both are rootless; since it's no gain in security in the container anyhow, disable it.
RUN echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/no-sandbox

# Enable source packages
RUN sed --in-place --regexp-extended "s/^# deb-src/deb-src/" /etc/apt/sources.list

# Update package list, upgrade to latest version, install necessary packages for
# early bootstrapping: .deb package configuration + locale generation.
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} apt-utils dialog libterm-readline-gnu-perl locales && \
    ${APT_UPGRADE} && ${APT_AUTOREMOVE} && ${APT_CLEAN} && ${APT_DELETE_LISTS}

# Disable exclusion of locales / translations / documentation (default in Ubuntu images)
RUN yes | /usr/local/sbin/unminimize

# Switch to fixed locale.
RUN locale-gen ${CONTAINER_LOCALE}
ENV LC_ALL ${CONTAINER_LOCALE}
ENV LANG ${CONTAINER_LOCALE}

# Bootstrapping is done, switch to working directory /tmp to continue setup.
WORKDIR /tmp

# Install package groups in defined order.
COPY /packages/01-base.lst .
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} $(sed -e "s/.*#.*//; /^$/d" 01-base.lst) && \
    ${APT_AUTOREMOVE} && ${APT_CLEAN} && ${APT_DELETE_LISTS}

COPY /packages/02-gcc.lst .
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} $(sed -e "s/.*#.*//; /^$/d" 02-gcc.lst) && \
    ${APT_AUTOREMOVE} && ${APT_CLEAN} && ${APT_DELETE_LISTS}

COPY /packages/03-custom-stack-dependencies.lst .
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} $(sed -e "s/.*#.*//; /^$/d" 03-custom-stack-dependencies.lst) && \
    ${APT_AUTOREMOVE} && ${APT_CLEAN} && ${APT_DELETE_LISTS}

COPY /packages/04-devtools.lst .
RUN ${APT_UPDATE} && \
    ${APT_INSTALL} $(sed -e "s/.*#.*//; /^$/d" 04-devtools.lst) && \
    ${APT_AUTOREMOVE} && ${APT_CLEAN} && ${APT_DELETE_LISTS}

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
    ${APT_AUTOREMOVE} && ${APT_CLEAN} && ${APT_DELETE_LISTS}

# Install Podman4 + dependencies from external source
COPY ./packages/binaries/*.deb /tmp/packages/
COPY ./packages/binaries/*.ddeb /tmp/packages/
RUN cd /tmp/packages && dpkg --install *.deb *.ddeb && rm -Rf /tmp/packages

# Install python packages
RUN python3 -m pip install --upgrade pip && \
    pip3 install hotdoc shyaml

# Install fonts needed for running WebKit layout tests
RUN git clone https://github.com/WebKitGTK/webkitgtk-test-fonts.git && \
    make -C webkitgtk-test-fonts DESTDIR="/usr/share" install && \
    rm -rf webkitgtk-test-fonts

# Podman proxy, connecting to host instance
COPY ./container_files/podman-host /usr/bin/podman-host

# Switch back to interactive prompt, when using apt.
ENV DEBIAN_FRONTEND dialog

# Debian package build settings
ENV DEBEMAIL "nzimmermann@igalia.com"
ENV DEBFULLNAME "Nikolas Zimmermann"
