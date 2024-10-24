#!/usr/bin/env bash

[ -z "${application_ready}" ] && { echo "[FATAL] You need to source 'utilities/application.sh' before sourcing this script."; return 1; }

host_setup_try_enable_localuser_authorization_for_x11() {

    _log_ ""

    local host_user_name=$(id --user --name)

    if type xhost >/dev/null 2>&1; then
        if xhost | grep --quiet "localuser:${host_user_name}"; then
            _log_ "-> The X11 localuser authorization for user '${host_user_name}' on host system is already enabled."
        else
            _log_ "-> Enable X11 localuser authorization for user '${host_user_name}' on host system..."
            xhost +"si:localuser:${host_user_name}"
        fi
    fi
}

host_setup_prerun_tasks() {

    host_setup_try_enable_localuser_authorization_for_x11
}