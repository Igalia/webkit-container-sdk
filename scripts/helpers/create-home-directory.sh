#!/usr/bin/bash -x
CONTAINER_HOME_DIRECTORY=${1}

# Create home directory, if not present.
if [ ! -d "${CONTAINER_HOME_DIRECTORY}" ]; then
  # Copy shell configuration skeleton files.
  cp -rv /etc/skel "${CONTAINER_HOME_DIRECTORY}"

  # Set ownership to current user.
  chown $(id -u):$(id -g) ${CONTAINER_HOME_DIRECTORY}

  # Don't let anyone see the content of that directory.
  chmod 750 ${CONTAINER_HOME_DIRECTORY}
fi

SHELL_NAME=$(basename ${SHELL})

# zsh quirk: suppress zsh-newuser-install first-time-login message.
if [ "${SHELL_NAME}" == "zsh" ]; then
    touch "${CONTAINER_HOME_DIRECTORY}"/.zshrc
fi
