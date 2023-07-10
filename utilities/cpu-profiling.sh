#!/usr/bin/env bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }
source "${WKDEV_SDK}/utilities/kernel-parameters.sh"

get_perf_event_kernel_setting() { echo "perf_event_paranoid"; }
get_perf_event_procfs_path() { echo "/proc/sys/kernel/$(get_perf_event_kernel_setting)"; }
get_preserved_perf_event_kernel_setting_file() { echo "${WKDEV_SDK}/.sysctl_setting_$(get_perf_event_kernel_setting)"; }
get_desired_perf_event_kernel_setting_value_for_profiling() { echo "-1"; }

# Helper function to explain the purpose of this setting
get_perf_settings_help_message() {
    cat <<EOF
    The host kernel parameters need to be modified, to allow capturing performance events by unprivileged users.
    The parameter 'kernel.$(get_perf_event_kernel_setting)' (exposed via procfs in '$(get_perf_event_procfs_path)')
    needs to be smaller than '2' (default) to allow using e.g. 'perf' based instrumentation on the host system / in the
    container. The lowest value '-1' allows unprivileged users to capture (almost) all events that 'root' can access.
EOF
}

# Helper function to enable CPU profiling related host kernel settings.
enable_perf_settings_for_cpu_profiling() {

    local perf_event_setting="$(get_perf_event_kernel_setting)"
    local current_value="$(read_kernel_parameter "${perf_event_setting}")"
    local desired_value="$(get_desired_perf_event_kernel_setting_value_for_profiling)"
    if [ "${current_value}" != "${desired_value}" ]; then
        echo "-> The kernel parameter 'kernel.${perf_event_setting}' needs to be modified to allow for CPU profiling (current value: '${current_value}'), switching to '${desired_value}'..."
        echo "${current_value}" > "$(get_preserved_perf_event_kernel_setting_file)"
        write_kernel_parameter "$(get_perf_event_kernel_setting)" "$(get_desired_perf_event_kernel_setting_value_for_profiling)"
    else
        echo "-> The kernel parameter 'kernel.${perf_event_setting}' is set to the correct value '${current_value}' - no need to modify."
    fi
}

# Helper function to disable CPU profiling related host kernel settings (and switch back to the original values).
disable_perf_settings_for_cpu_profiling() {

    local perf_event_setting="$(get_perf_event_kernel_setting)"
    local perf_event_preserved_file="$(get_preserved_perf_event_kernel_setting_file)"
    if [ -f "${perf_event_preserved_file}" ]; then
        local current_value="$(read_kernel_parameter "${perf_event_setting}")"
        local preserved_value="$(cat "${perf_event_preserved_file}")"
        echo "-> Restoring kernel parameter 'kernel.${perf_event_setting}' (current value: '${current_value}') to its original value '${preserved_value}'..."
        write_kernel_parameter "$(get_perf_event_kernel_setting)" "${preserved_value}"
        rm -f "${perf_event_preserved_file}"
    else
        echo "-> The kernel parameter 'kernel.${perf_event_setting}' was not modified by the SDK -- no need to restore a value."
    fi
}
