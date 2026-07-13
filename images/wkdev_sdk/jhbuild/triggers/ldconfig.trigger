# Update the dynamic linker cache after a module installs shared libraries.
# The SDK build runs JHBuild as root and registers its fixed installation
# prefix in /etc/ld.so.conf.d/wkdev-sdk.conf.

# IfExecutable: ldconfig
# REMatch: /lib(?:/[^/]+)*/[^/]+\.so(?:\.[0-9]+)*$

if [ "$(id -u)" -eq 0 ]; then
    ldconfig
fi
