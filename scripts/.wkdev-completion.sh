#!/usr/bin/env bash
# Copyright 2024 Igalia S.L.
# SPDX-License: MIT

_wkdev_completions()
{
  local dir
  local words=()
  
  # Create array of wkdev- words.
  dir=$(dirname $(which wkdev))
  while read each; do
    each=$(basename "$each")
    if [[ "$each" == wkdev-* ]]; then
      words+=(${each:6})
    fi
  done <<< $(find $dir -type f -print)
  
  # Expand array to string.
  words=${words[@]}
  # Set autocomplete words for wkdev.
  COMPREPLY=($(compgen -W "${words}" "${COMP_WORDS[1]}"))
} 
complete -F _wkdev_completions wkdev
