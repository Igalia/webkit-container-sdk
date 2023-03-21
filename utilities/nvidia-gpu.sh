#!/usr/bin/bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }
source "${WKDEV_SDK}/utilities/prerequisites.sh"

verify_executable_exists lsmod

is_nvidia_kernel_module_loaded() {

    # Check kernel modules named 'nvidia...' are loaded.
    local nvidia_modules=$(lsmod | grep --count "^nvidia")
    [ ${nvidia_modules} -gt 0 ] || return 1
    return 0
}

is_nvidia_gpu_installed() {

    is_nvidia_kernel_module_loaded || return 1

    # Check NVIDIA tools are available.
    does_executable_exist nvidia-smi || return 1

    # Check nvidia-smi returns an zero exit code.
    run_command_silent nvidia-smi || return 1

    return 0
}

# This distribution also works for 22.10 -- has no official support though.
get_nvidia_ubuntu_distribution() { echo "ubuntu22.04"; } # -> symlinks to ubuntu18.04, their only packages
get_nvidia_host_package() { echo "nvidia-container-toolkit-base"; } # to be installed on host to create CDI specs
get_nvidia_container_package() { echo "nvidia-utils-525"; }         # to be installed in the container to have 'nvidia-smi' available

get_nvidia_repository_name() { echo "libnvidia-container"; }
get_nvidia_repository_url() { echo "https://nvidia.github.io/$(get_nvidia_repository_name)"; }
get_nvidia_apt_source_file() { echo "/etc/apt/sources.list.d/$(get_nvidia_repository_name).list"; }
get_nvidia_gpg_key_file() { echo "/etc/apt/trusted.gpg.d/$(get_nvidia_repository_name).gpg"; }
get_nvidia_cdi_config_file() { echo "/etc/cdi/nvidia.yaml"; }
get_nvidia_gpu_profiling_conf_file() { echo "/etc/modprobe.d/nvidia-gpu-profiling.conf"; }
