#!/usr/bin/bash

[ ! -z "${application_ready}" ] && { echo "[FATAL] You are not allowed to source 'utilities/application.sh' more than once." && return 1; }

# This script fragment provides the following global variables after sourcing.
#
# 1. ${application_name} - Name of the application - equal to the filename of the script.
# 2. ${application_description} - Description of the application - a few words about the purpose.
#
# The 'init_application' method serves as common entry point for all scripts in the wkdev-sdk.
# Is is assumed that all scripts call 'init_application' in their preamble, before executing any logic.

# Exposed global variables.
application_name=""
application_description=""

# Hidden "local" variables, in the form of functions.
container_detection_file() { echo "/run/.containerenv"; }

# Add log message to stdout.
_log_() {
    local log_message="${1-}"
    printf "${log_message}\n"
}

# Aborts the application/script.
# Requires an error message as first parameter, and an optional exit code as second parameter.
_abort_() {
    local error_message="${1-}"
    local exit_code="${2-}"
    if [ -z "${exit_code}" ]; then
        exit_code=1
    fi

    printf "\n[FATAL] ${error_message} - aborting with exit code ${exit_code}.\n"
    exit ${exit_code}
}

init_application() {

    # Bash script recommendations, see https://www.davidpashley.com/articles/writing-robust-shell-scripts/.

    # All wkdev-sdk scripts...
    set +o errexit  # ... do not auto-abort if any sub-command fails with a non-zero exit code.
                    # (see http://mywiki.wooledge.org/BashFAQ/105 for pros/cons).

    set -o nounset  # ... abort if any unset variable is read (very useful during development).
                    # (see http://mywiki.wooledge.org/BashFAQ/112 for pros/cons).

    # set -o pipefail is only enabled where necessary.

    # The callee needs to pass its "${0}" value as first parameter to 'init_application'
    # and a short description of the application's purpose as second parameter.
    application_name=$(basename "${1}")   # e.g. "foobar.sh" if ${1}="/absolute/path/to/wkdev-sdk/foobar.sh"
    application_description="${2}"        #      "First foobar.sh implementation ever"

    local application_constraints="${3-}" # Either "container-only", "host-only" or "host-and-container".
    if [ "${application_constraints}" = "container-only" ]; then
        # Prevent application to run on the host.
        [ ! -f "$(container_detection_file)" ] && _abort_ "The script '${application_name}' is intended to run from within the container only"
    elif [ "${application_constraints}" = "host-only" ]; then
        # Prevent application to run within the container.
        [ -f "$(container_detection_file)" ] && _abort_ "The script '${application_name}' is intended to run on the host only"
    elif [ "${application_constraints}" = "host-and-container" ]; then
        true # no-op
    else
       _abort_ "Unknown constraints '${application_constraints}' passed as third parameter to 'init_application'"
    fi
}

run_application() {
    _log_ "${application_name}: ${application_description}"
}

# Remmeber that we've processed and loaded this script fragment - it's safe now to include others.
application_ready=1
source "${WKDEV_SDK}/utilities/bash-argsparse/argsparse.sh"
