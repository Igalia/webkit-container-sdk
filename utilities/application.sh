#!/usr/bin/env bash

[ ! -z "${application_ready}" ] && { echo "[FATAL] You are not allowed to source 'utilities/application.sh' more than once."; return 1; }

# Exposed global variables.
application_name=""
application_directory=""
application_description=""

# This script fragment provides the following global variables after sourcing.
#
# 1. ${application_name} - Name of the application - equal to the filename of the script.
# 2. ${application_directory} - Directory name where the application resides.
# 3. ${application_description} - Description of the application - a few words about the purpose.
#
# The 'init_application' method serves as common entry point for all scripts in the wkdev-sdk.
# Is is assumed that all scripts call 'init_application' in their preamble, before executing any logic.

log_to_stdout_enabled=1  # Disabled by --quiet.
quiet_args=()            # Contains --quiet if --quiet is passed in argv, used
                         # to propagate it to other scripts.
app_argv=("${@}")        # init_application requires argv to check for --quiet.

enable_quiet_support() {
    # Register the option for the sake of --help.
    argsparse_use_option =quiet "Silence all WebKit container SDK messages (use this when you need \
to launch a program in the container from the host with clean output)"

    # We do the argument parsing ourselves instead of with argsparse
    # as we need to know whether we need to be quiet before printing the
    # application description message, before the application has set all
    # its own argsparse settings.
    for flag in "${app_argv[@]}"; do
        case "${flag}" in
            --quiet|-q)
                log_to_stdout_enabled=0
                quiet_args=(--quiet)
                ;;
            --)
                break
                ;;
        esac
    done
}

# Add log message to stdout.
_log_() {

    local log_message="${1-}"
    if [ $log_to_stdout_enabled -eq 1 ]; then
        echo "${log_message}"
    fi
    # Log to journald if available. This can help users troubleshoot issues when
    # using `wkdev-enter --quiet` inside scripts.
    logger -p local0.info -t "${application_name}" -- "${log_message}" || true
}

# Aborts the application/script.
# Requires an error message as first parameter, and an optional exit code as second parameter.
_abort_() {

    local error_message="${1-}"
    local exit_code="${2-}"
    if [ -z "${exit_code}" ]; then
        exit_code=1
    fi

    printf "\n[FATAL] ${error_message} - aborting with exit code ${exit_code}.\n" >&2
    exit ${exit_code}
}

# Runs a command.
run_command() {

    local command="${1}"
    shift

    "${command}" "${@}"
}

# Runs a command suppressing both stdout and stderr output.
run_command_silent() {

    local command="${1}"
    shift

    "${command}" "${@}" &>/dev/null
}

# Runs a command suppressing both stdout and stderr output,
# unless '--verbose' was passed as option to the script.
run_command_silent_unless_verbose() {

    local command="${1}"
    shift

    if argsparse_is_option_set "verbose"; then
        "${command}" "${@}"
    else
        "${command}" "${@}" &>/dev/null
    fi
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
    local application_path="${0}"
    application_name=$(basename "${application_path}")
    application_directory=$(cd "$(dirname "${application_path:-${PWD}}")" &>/dev/null && pwd)
    application_description="${2}"

    local application_constraints="${3-}" # Either "container-only", "host-only" or "host-and-container".
    if [ "${application_constraints}" = "container-only" ]; then
        # Prevent application to run on the host.
        is_running_in_wkdev_sdk_container || _abort_ "The script '${application_name}' is intended to run from within the wkdev-sdk container only"
    elif [ "${application_constraints}" = "host-only" ]; then
        # Prevent application to run within the container.
        is_running_in_wkdev_sdk_container && _abort_ "The script '${application_name}' is intended to run on the host only"
    elif [ "${application_constraints}" = "host-and-container" ]; then
        true # no-op
    else
       _abort_ "Unknown constraints '${application_constraints}' passed as third parameter to 'init_application'"
    fi

    local extra_options="${4-}" # Currently either "with-quiet-support" or nothing
    if [ "${extra_options}" == "with-quiet-support" ]; then
        enable_quiet_support
    fi

    [ -z "${application_description}" ] || _log_ "${application_name}: ${application_description}"
}

# Remember that we've processed and loaded this script fragment - it's safe now to include others.
application_ready=1
source "${WKDEV_SDK}/utilities/bash-argsparse/argsparse.sh"
source "${WKDEV_SDK}/utilities/settings.sh"
