#!/bin/bash
# Disk usage helper for the weekly maintenance workflow.
#
# Usage:
#   disk-usage.sh snapshot <output-file> <label>
#   disk-usage.sh compare  <beforeprune.txt> <afterprune.txt> <afterbuild.txt>
#
# `snapshot` captures filesystem + podman storage usage to <output-file>,
# emitting both machine-readable KEY=VALUE lines and a human-readable
# section in one go (df and du are each run only once).
#
# `compare` reads three snapshot files and prints the freed-space /
# build-cost summary. Also writes a markdown table to $GITHUB_STEP_SUMMARY
# when present.

set -euo pipefail

# Format a byte count as human-readable, preserving sign. Falls back to raw bytes if numfmt isn't available.
human() {
  local n="$1"
  local sign=""
  if [[ "$n" =~ ^- ]]; then
    sign="-"
    n="${n#-}"
  fi
  if command -v numfmt >/dev/null 2>&1; then
    echo "${sign}$(numfmt --to=iec --suffix=B --format='%.2f' "$n")"
  else
    echo "${sign}${n} bytes"
  fi
}

# Return VALUE from a KEY=VALUE entry from a snapshot file.
get_val() {
  grep -E "^$2=" "$1" | head -1 | cut -d= -f2-
}

action_snapshot() {
  local OUT="${1:?Usage: $0 snapshot <output-file> <label>}"
  local LABEL="${2:?Usage: $0 snapshot <output-file> <label>}"

  local GRAPHROOT
  GRAPHROOT="$(podman info --format '{{.Store.GraphRoot}}')"

  local fs_line FS_SIZE FS_USED FS_AVAIL
  fs_line=$(df -B1 --output=size,used,avail "$GRAPHROOT" | tail -1)
  read -r FS_SIZE FS_USED FS_AVAIL <<<"$fs_line"

  local PODMAN_SIZE
  PODMAN_SIZE=$(sudo du -sb "$GRAPHROOT" 2>/dev/null | awk 'NR==1{print $1}' || true)
  PODMAN_SIZE="${PODMAN_SIZE:-0}"

  {
    echo "=== $LABEL ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
    echo
    echo "## Machine-readable (bytes)"
    echo "FS_SIZE=$FS_SIZE"
    echo "FS_USED=$FS_USED"
    echo "FS_AVAIL=$FS_AVAIL"
    echo "PODMAN_SIZE=$PODMAN_SIZE"
    echo "GRAPHROOT=$GRAPHROOT"
    echo
    echo "## Graphroot filesystem ($GRAPHROOT)"
    echo "  Size:      $(human "$FS_SIZE")"
    echo "  Used:      $(human "$FS_USED")"
    echo "  Available: $(human "$FS_AVAIL")"
    echo
    echo "## Podman storage size"
    echo "  $(human "$PODMAN_SIZE")"
    echo
    echo "## df -h (all mounts, for context)"
    df -h
    echo
    echo "## podman system df"
    podman system df
    echo
    echo "## podman system df -v"
    podman system df -v
    echo
  } | tee "$OUT"
}


action_compare() {
  local BEFOREPRUNE="${1:?Usage: $0 compare <beforeprune> <afterprune> <afterbuild>}"
  local AFTERPRUNE="${2:?Usage: $0 compare <beforeprune> <afterprune> <afterbuild>}"
  local AFTERBUILD="${3:?Usage: $0 compare <beforeprune> <afterprune> <afterbuild>}"

  local BP_AVAIL AP_AVAIL AB_AVAIL BP_PODMAN AP_PODMAN AB_PODMAN
  BP_AVAIL=$(get_val "$BEFOREPRUNE" FS_AVAIL)
  AP_AVAIL=$(get_val "$AFTERPRUNE" FS_AVAIL)
  AB_AVAIL=$(get_val "$AFTERBUILD" FS_AVAIL)
  BP_PODMAN=$(get_val "$BEFOREPRUNE" PODMAN_SIZE)
  AP_PODMAN=$(get_val "$AFTERPRUNE" PODMAN_SIZE)
  AB_PODMAN=$(get_val "$AFTERBUILD" PODMAN_SIZE)

  local FREED_BY_CYCLE=$(( AB_AVAIL - BP_AVAIL ))
  local BUILD_COST=$(( AP_AVAIL - AB_AVAIL ))
  local PODMAN_NET=$(( AB_PODMAN - BP_PODMAN ))
  local PODMAN_BUILD=$(( AB_PODMAN - AP_PODMAN ))
  local PODMAN_PRUNED=$(( BP_PODMAN - AP_PODMAN ))

  cat <<EOF

============================================================
            WEEKLY PODMAN MAINTENANCE SUMMARY
============================================================

Filesystem available space:
  Before prune:  $(human "$BP_AVAIL")
  After  prune:  $(human "$AP_AVAIL")
  After  build:  $(human "$AB_AVAIL")

Podman storage size (graphroot du):
  Before prune:  $(human "$BP_PODMAN")
  After  prune:  $(human "$AP_PODMAN")
  After  build:  $(human "$AB_PODMAN")

------------------------------------------------------------
Key metrics
------------------------------------------------------------

1) Net space freed by this cycle (AfterPruneAndBuild vs BeforePrune)
   $(human "$FREED_BY_CYCLE")

2) How much space the freshly built image needs (AfterPrune vs AfterPruneAndBuild)
   $(human "$BUILD_COST")

------------------------------------------------------------
Podman storage deltas (for context)
------------------------------------------------------------

  Pruned out (BeforePrune - AfterPrune):              $(human "$PODMAN_PRUNED")
  Added by build (AfterPruneAndBuild - AfterPrune):   $(human "$PODMAN_BUILD")
  Net change (AfterPruneAndBuild - BeforePrune):      $(human "$PODMAN_NET")

============================================================
EOF

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## Weekly podman maintenance summary"
      echo
      echo "| Metric | Value |"
      echo "|---|---|"
      echo "| Net space freed (AfterPruneAndBuild - BeforePrune) | $(human "$FREED_BY_CYCLE") |"
      echo "| Build cost (AfterPrune - AfterPruneAndBuild) | $(human "$BUILD_COST") |"
      echo "| Pruned out (BeforePrune - AfterPrune) | $(human "$PODMAN_PRUNED") |"
      echo "| Added by build (AfterPruneAndBuild - AfterPrune) | $(human "$PODMAN_BUILD") |"
      echo "| Podman storage net change (AfterPruneAndBuild - BeforePrune) | $(human "$PODMAN_NET") |"
      echo
      echo "### Filesystem available"
      echo "- BeforePrune: \`$(human "$BP_AVAIL")\`"
      echo "- AfterPrune:  \`$(human "$AP_AVAIL")\`"
      echo "- AfterPruneAndBuild:  \`$(human "$AB_AVAIL")\`"
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

# main

ACTION="${1:-}"
case "$ACTION" in
  snapshot)
    shift
    action_snapshot "$@"
    ;;
  compare)
    shift
    action_compare "$@"
    ;;
  ""|-h|--help|help)
    cat <<EOF
Usage:
  $0 snapshot <output-file> <label>
  $0 compare  <beforeprune.txt> <afterprune.txt> <afterbuild.txt>
EOF
    [[ -z "$ACTION" ]] && exit 1 || exit 0
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    echo "Run '$0 --help' for usage." >&2
    exit 1
    ;;
esac
