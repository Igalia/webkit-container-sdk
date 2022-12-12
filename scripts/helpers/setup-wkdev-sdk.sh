#!/usr/bin/bash

DIALOG_OPTIONS="--keep-tite --colors"
LAST_RADIO_CHOICE=""

WKDEV_SDK=${PWD}
if [ ! -d "${WKDEV_SDK}/defaults" ]; then
  echo "You have to launch setup-wkdev-sdk.sh from the root of the wkdev-sdk Git repository: scripts/helpers/setup-wkdev-sdk.sh"
  exit 1
fi

function dialog_show_message_box {
  message=${1}
  height=${2}
  dialog ${DIALOG_OPTIONS} --msgbox "${message}" ${height} 100
}

function dialog_show_radio_list {
  message=${1}
  radio_options=${2}
  list_height=${3}
  LAST_RADIO_CHOICE=`dialog ${DIALOG_OPTIONS} --radiolist "${message}" 0 100 ${list_height} "${radio_options[@]}" 3>&1 1>&2 2>&3`
}

function prompt_user_for_choice {
  file_name=${1}

  container_home_file_location="${HOME}/${file_name}"
  [ ! -f "${container_home_file_location}" ]
  has_container_home_file=$?

  host_home_file_location="${DISTROBOX_HOST_HOME}/${file_name}"
  [ ! -f "${host_home_file_location}" ]
  has_host_home_file=$?

  sdk_default_file_location="${WKDEV_SDK}/defaults/${file_name}"
  [ ! -f "${sdk_default_file_location}" ]
  has_sdk_default_file=$?

  echo ""
  echo "Processing ${file_name}, has_container_home_file=${has_container_home_file}, has_host_home_file=${has_host_home_file}, has_sdk_default_file=${has_sdk_default_file}..."

  if [ ${has_container_home_file} -eq 0 ] && [ ${has_host_home_file} -eq 0 ] && [ ${has_sdk_default_file} -eq 0 ]; then
    echo "-> Nothing to do, the file doesn't exist in any location."
    return
  fi

  radio_options=( )
  if [ ${has_container_home_file} -eq 1 ]; then
    radio_options+=( Keep "Keep file copied from host /etc/skel during container home directory creation." on )
  else
    radio_options+=( Continue "Do nothing: don't create the config file in the container home directory." on )
  fi

  if [ ${has_host_home_file} -eq 1 ]; then
    radio_options+=( Copy "Copy file from host home directory" off )
  fi 

  if [ ${has_sdk_default_file} -eq 1 ]; then
    radio_options+=( Use "Use wkdev-sdk supplied default configuration" off )
  fi 

  message="Please choose how to setup \Z1\Zb${HOME}/${file_name}\Zn:"
  dialog_show_radio_list "${message}" ${radio_options} 3

  if [ "${LAST_RADIO_CHOICE}" == "" ]; then
    echo "-> Skipping \"${file_name}\" setup, user cancelled."
  elif [ "${LAST_RADIO_CHOICE}" == "Keep" ] || [ "${LAST_RADIO_CHOICE}" == "Continue" ]; then
    echo "-> Skipping \"${file_name}\" setup, nothing to do."
  elif [ "${LAST_RADIO_CHOICE}" == "Use" ]; then
    echo "-> Copy ${sdk_default_file_location} to ${HOME}..."
    cp -f ${sdk_default_file_location} ${HOME}
  elif [ "${LAST_RADIO_CHOICE}" == "Copy" ]; then
    echo "-> Copy ${host_home_file_location} to ${HOME}..."
    cp -f ${host_home_file_location} ${HOME}
  fi
}

SHELL_NAME=$(basename ${SHELL})

# 1) Shell settings
if [ "${SHELL_NAME}" == "bash" ] || [ "${SHELL_NAME}" == "zsh" ]; then
  message="Starting shell configuration, for your shell \Z2\Zb${SHELL_NAME}\Zn.\n\n\
The wizard will now ask you some questions about your desired environment..."
  dialog_show_message_box "${message}" 10

  if [ "${SHELL_NAME}" == "bash" ]; then
    prompt_user_for_choice ".bash_profile"
    prompt_user_for_choice ".bash_login"
    prompt_user_for_choice ".profile"
    prompt_user_for_choice ".bashrc"
    prompt_user_for_choice ".bash_logout"
  elif [ "${SHELL_NAME}" == "zsh" ]; then
    prompt_user_for_choice ".zshenv"
    prompt_user_for_choice ".zprofile"
    prompt_user_for_choice ".zshrc"
    prompt_user_for_choice ".zlogin"
    prompt_user_for_choice ".zlogout"
  fi
else
  message="Your shell \Z1\Zb${SHELL_NAME}\Zn is not supported - you have to \
manually configure its settings, by either copying the configuration files \
from the host home directory \Z1\Zb\$DISTROBOX_HOST_HOME\Zn to the container \
home directory \Z1\Zb\$HOME\Zn or by writing new ones from scratch.\n\n\
\Z1\Zb\$SHELL:\Zn               ${SHELL}\n\
\Z1\Zb\$HOME:\Zn                ${HOME}\n\
\Z1\Zb\$DISTROBOX_HOST_HOME:\Zn ${DISTROBOX_HOST_HOME}\n\n\
Skipping shell configuration, continuing setup..."
  dialog_show_message_box "${message}" 15
fi

# 2) GDB settings
prompt_user_for_choice ".gdbinit"

# TODO: Extend for other things.
