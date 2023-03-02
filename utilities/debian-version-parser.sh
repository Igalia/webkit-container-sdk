#!/usr/bin/bash

# man 7 deb-version: Debian package version number format
#    [epoch:]upstream-version[-debian-revision]
#
# epoch:
#    This is a single (generally small) unsigned integer. It may be omitted,
#    in which case zero is assumed. If it is omitted then the upstream-version
#    may not contain any colons.
#
# upstream-version:
#    The upstream-version may contain only alphanumerics ("A-Za-z0-9") and
#    the characters . + - : ~ (full stop, plus, hyphen, colon, tilde) and
#    should start with a digit. If there is no debian-revision then hyphens
#    are not allowed; if there is no epoch then colons are not allowed.
#
# debian-revision:
#    It is optional; if it isn't present then the upstream-version may not
#    contain a hyphen.
#
# Notes:
# Dpkg will break the version number apart at the last hyphen in the string (if there is one)
# to determine the upstream-version and debian-revision. The absence of a debian-revision
# compares earlier than the presence of one (but note that the debian-revision is the least
# significant part of the version number).

compose_debian_version_string() {
    local -n string=${1}
    local version_epoch=${2}
    local version_upstream_version=${3}
    local version_debian_revision=${4}

    string="${version_upstream_version}-${version_debian_revision}"
    if [ ${version_epoch} -ne 0 ]; then
        string="${version_epoch}:${string}"
    fi
}

parse_debian_version_string() {
    local string=${1}
    local -n version_epoch=${2}
    local -n version_upstream_version=${3}
    local -n version_debian_revision=${4}

    # If the string contains a hyphen, the rightmost determines the split point: epoch+upstream_version to the left, debian_revision to the right
    local epoch_and_upstream_version="${string}"
    if [[ "${string}" =~ "-" ]]; then
        epoch_and_upstream_version="$(echo "${string}" | sed --expression 's/\(.*\)-.*/\1/')"
        version_debian_revision="$(echo "${string}" | sed --expression 's/.*-\(.*\)/\1/')"
    fi

     # If the substring contains a colon, then an epoch must be present to be well-formed.
     if [[ "${epoch_and_upstream_version}" =~ ":" ]]; then
         version_epoch=$(echo "${epoch_and_upstream_version}" | sed --expression 's/\(.*\):.*/\1/')
         version_upstream_version="$(echo "${epoch_and_upstream_version}" | sed --expression 's/.*:\(.*\)/\1/')"
     else
         version_epoch=0
         version_upstream_version="${epoch_and_upstream_version}"
     fi
}

parse_debian_package_string() {
    local string=${1}
    local -n parsed_package_name=${2}
    local -n parsed_epoch=${3}
    local -n parsed_upstream_version=${4}
    local -n parsed_debian_revision=${5}

    # If the string contains an underscore, the rightmost determines the split point: package_name to the left, debian_version to the right
    if [[ "${string}" =~ "_" ]]; then
        parsed_package_name="$(echo "${string}" | sed --expression 's/\(.*\)_.*/\1/')"
        local debian_version="$(echo "${string}" | sed --expression 's/.*_\(.*\)/\1/')"
        parse_debian_version_string "${debian_version}" parsed_epoch parsed_upstream_version parsed_debian_revision
    else
        echo "-> Package version string '${string}' ill-formed. Cannot parse."
        exit 1
    fi
}
