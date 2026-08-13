#!/bin/bash
# Disk usage helper for the podman storage maintenance workflow.
#
# Usage:
#   disk-usage.sh snapshot <output-file> <label>
#   disk-usage.sh compare  <beforereset.txt> <afterreset.txt> <afterbuild.txt>
#   disk-usage.sh check    [min-free-gb]
#
# `snapshot` captures filesystem + podman storage usage to <output-file>,
# emitting both machine-readable KEY=VALUE lines and a human-readable
# section in one go (df and du are each run only once). It always deletes a
# pre-existing <output-file> first, so a failed run can never leave a stale
# snapshot behind: when it fails, no file is written at all. If only the
# optional du measurement of the graphroot fails, the snapshot is still
# written (and succeeds) with PODMAN_SIZE=unknown.
#
# `compare` reads three snapshot files and prints the freed-space /
# build-cost summary. Also writes a markdown table to $GITHUB_STEP_SUMMARY
# when present. If any of the three files is missing or has unexpected
# content, the comparison is skipped with a note explaining why. A snapshot
# with PODMAN_SIZE=unknown is still accepted: the filesystem metrics are
# reported normally and only the affected podman storage deltas degrade to
# "not measured".
#
# `check` reports whether the free space on the podman graphroot filesystem
# is at least <min-free-gb> GiB (default: ${DEFAULT_MIN_FREE_GB}). This is the
# single source of truth for the low-disk threshold the maintenance workflow
# uses to decide whether a reset is actually needed.
#
# Exit status convention (all actions): 0 = did what was asked; 1 =
# meaningful negative result (check: disk below threshold); 2 = could not
# operate (podman broken, snapshot files missing or invalid, bad argument).
# The script always reports failure honestly; callers decide where a
# non-zero status is tolerable.

set -euo pipefail

DEFAULT_MIN_FREE_GB=50

# Format a byte count as human-readable, preserving sign. Falls back to raw bytes if numfmt isn't available.
human() {
  local n="$1"
  local sign=""
  if [[ "$n" =~ ^- ]]; then
    sign="-"
    n="${n#-}"
  fi
  if [[ ! "$n" =~ ^[0-9]+$ ]]; then
    # Not a byte count (e.g. "unknown"): pass it through untouched.
    echo "$1"
    return
  fi
  if command -v numfmt >/dev/null 2>&1; then
    echo "${sign}$(numfmt --to=iec-i --suffix=B --format='%.2f' "$n")"
  else
    echo "${sign}${n} bytes"
  fi
}

# Render a byte count, or "not measured" when it is not a number (a snapshot
# recorded PODMAN_SIZE=unknown). Same wording as delta() below, so a report
# never mixes vocabularies for the same gap.
size() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    human "$1"
  else
    echo "not measured"
  fi
}

# Subtract two byte counts ($1 - $2) and render the result. Prints "not
# measured" when either operand is not a number, so the caller reports an
# honest gap instead of a fabricated delta. Deltas degrade one by one: a
# delta between two measured snapshots is still a real number even when a
# third snapshot could not be measured.
delta() {
  if [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ ]]; then
    human "$(( $1 - $2 ))"
  else
    echo "not measured"
  fi
}

# Return VALUE from a KEY=VALUE entry from a snapshot file.
get_val() {
  grep -E "^$2=" "$1" | head -1 | cut -d= -f2-
}

graphroot() {
  podman info --format '{{.Store.GraphRoot}}'
}

action_snapshot() {
  local OUT="${1:?Usage: $0 snapshot <output-file> <label>}"
  local LABEL="${2:?Usage: $0 snapshot <output-file> <label>}"

  # Never leave a file from a previous run behind: if this run can't produce
  # a snapshot, compare must find a missing file, not stale data.
  rm -f "$OUT" "$OUT.tmp"

  local GRAPHROOT
  if ! GRAPHROOT="$(graphroot)"; then
    echo "warning: podman is not functional (podman info failed): no snapshot taken" >&2
    return 2
  fi

  local fs_line FS_SIZE FS_USED FS_AVAIL
  if ! fs_line=$(df -B1 --output=size,used,avail "$GRAPHROOT" | tail -1); then
    echo "warning: cannot query the filesystem of $GRAPHROOT: no snapshot taken" >&2
    return 2
  fi
  read -r FS_SIZE FS_USED FS_AVAIL <<<"$fs_line"

  # For rootless podman the storage contains files owned by subuids, which
  # plain du can't stat; podman unshare enters the user namespace where they
  # are readable. Fall back to plain du (rootful podman) if that fails.
  # Only a du that exited successfully is trusted: a du that failed partway
  # (e.g. unreadable subdirectories) still prints a grand total, but that
  # total is an undercount and must not be recorded as a real measurement.
  local PODMAN_SIZE="" du_out
  if du_out=$(podman unshare du -sb "$GRAPHROOT" 2>/dev/null) \
      || du_out=$(du -sb "$GRAPHROOT" 2>/dev/null); then
    PODMAN_SIZE=$(awk 'NR==1{print $1}' <<<"$du_out")
    [[ "$PODMAN_SIZE" =~ ^[0-9]+$ ]] || PODMAN_SIZE=""
  fi
  # PODMAN_SIZE is "unknown" (never a fake 0) when neither du method could
  # fully traverse the graphroot. This deliberately does NOT fail the
  # snapshot: podman itself may be perfectly healthy and the filesystem
  # statistics remain useful. The non-numeric value makes compare report the
  # affected storage deltas as "not measured" instead of fabricating them
  # from a placeholder.
  PODMAN_SIZE="${PODMAN_SIZE:-unknown}"

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
    df -h || echo "(df -h failed; an unrelated mount may be dead)"
    echo
    echo "## podman system df"
    podman system df || echo "(podman system df failed)"
    echo
    echo "## podman system df -v"
    podman system df -v || echo "(podman system df -v failed)"
    echo
  } | tee "$OUT.tmp"
  # Publish the snapshot only once it is complete: whatever fails mid-block
  # above must never leave a partial file that compare would accept as valid.
  mv "$OUT.tmp" "$OUT"
}

action_compare() {
  local BEFORERESET="${1:?Usage: $0 compare <beforereset> <afterreset> <afterbuild>}"
  local AFTERRESET="${2:?Usage: $0 compare <beforereset> <afterreset> <afterbuild>}"
  local AFTERBUILD="${3:?Usage: $0 compare <beforereset> <afterreset> <afterbuild>}"

  # A snapshot may legitimately not exist (snapshot writes no file when
  # podman is broken). Refuse to compare against missing or unexpected
  # content instead of failing cryptically or producing garbage numbers.
  local f
  for f in "$BEFORERESET" "$AFTERRESET" "$AFTERBUILD"; do
    if [[ ! -f "$f" ]] \
        || [[ "$(grep -cE '^FS_AVAIL=[0-9]+$' "$f")" -ne 1 ]] \
        || [[ "$(grep -cE '^PODMAN_SIZE=([0-9]+|unknown)$' "$f")" -ne 1 ]]; then
      echo "warning: snapshot '$f' is missing or incomplete (was podman broken when it should have been taken?): skipping comparison"
      if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        echo "Comparison skipped: snapshot \`$f\` is missing or incomplete." >> "$GITHUB_STEP_SUMMARY"
      fi
      return 2
    fi
  done

  local B_RESET_AVAIL A_RESET_AVAIL A_BUILD_AVAIL B_RESET_PODMAN A_RESET_PODMAN A_BUILD_PODMAN
  B_RESET_AVAIL=$(get_val "$BEFORERESET" FS_AVAIL)
  A_RESET_AVAIL=$(get_val "$AFTERRESET"  FS_AVAIL)
  A_BUILD_AVAIL=$(get_val "$AFTERBUILD"  FS_AVAIL)
  B_RESET_PODMAN=$(get_val "$BEFORERESET" PODMAN_SIZE)
  A_RESET_PODMAN=$(get_val "$AFTERRESET"  PODMAN_SIZE)
  A_BUILD_PODMAN=$(get_val "$AFTERBUILD"  PODMAN_SIZE)

  local FREED_BY_CYCLE=$((  A_BUILD_AVAIL  - B_RESET_AVAIL  ))
  local BUILD_COST=$((      A_RESET_AVAIL  - A_BUILD_AVAIL  ))

  # PODMAN_SIZE may be "unknown" in any snapshot (du could not traverse the
  # graphroot when it was taken). The filesystem numbers above are still
  # valid and are the key metrics, so only the deltas touching an unknown
  # measurement degrade to "not measured".
  local PODMAN_NET PODMAN_BUILD PODMAN_REMOVED
  PODMAN_NET=$(delta     "$A_BUILD_PODMAN" "$B_RESET_PODMAN")
  PODMAN_BUILD=$(delta   "$A_BUILD_PODMAN" "$A_RESET_PODMAN")
  PODMAN_REMOVED=$(delta "$B_RESET_PODMAN" "$A_RESET_PODMAN")
  if [[ "${PODMAN_NET}${PODMAN_BUILD}${PODMAN_REMOVED}" == *"not measured"* ]]; then
    echo "warning: at least one snapshot could not measure the podman storage size: the filesystem numbers below are complete, the affected podman deltas read \"not measured\""
  fi

  cat <<EOF

============================================================
            PODMAN STORAGE MAINTENANCE SUMMARY
============================================================

Filesystem available space:
  Before reset:  $(human "$B_RESET_AVAIL")
  After  reset:  $(human "$A_RESET_AVAIL")
  After  build:  $(human "$A_BUILD_AVAIL")

Podman storage size (graphroot du):
  Before reset:  $(size "$B_RESET_PODMAN")
  After  reset:  $(size "$A_RESET_PODMAN")
  After  build:  $(size "$A_BUILD_PODMAN")

------------------------------------------------------------
Key metrics
------------------------------------------------------------

1) Net space freed by this cycle (AfterBuild vs BeforeReset)
   $(human "$FREED_BY_CYCLE")

2) How much space the freshly built image needs (AfterReset vs AfterBuild)
   $(human "$BUILD_COST")

------------------------------------------------------------
Podman storage deltas (for context)
------------------------------------------------------------

  Removed by reset (BeforeReset - AfterReset):  ${PODMAN_REMOVED}
  Added by build  (AfterBuild - AfterReset):    ${PODMAN_BUILD}
  Net change      (AfterBuild - BeforeReset):   ${PODMAN_NET}

============================================================
EOF

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## Podman storage maintenance summary"
      echo
      echo "| Metric | Value |"
      echo "|---|---|"
      echo "| Net space freed (AfterBuild - BeforeReset) | $(human "$FREED_BY_CYCLE") |"
      echo "| Build cost (AfterReset - AfterBuild) | $(human "$BUILD_COST") |"
      echo "| Removed by reset (BeforeReset - AfterReset) | ${PODMAN_REMOVED} |"
      echo "| Added by build (AfterBuild - AfterReset) | ${PODMAN_BUILD} |"
      echo "| Podman storage net change (AfterBuild - BeforeReset) | ${PODMAN_NET} |"
      echo
      echo "### Filesystem available"
      echo "- BeforeReset: \`$(human "$B_RESET_AVAIL")\`"
      echo "- AfterReset:  \`$(human "$A_RESET_AVAIL")\`"
      echo "- AfterBuild:  \`$(human "$A_BUILD_AVAIL")\`"
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

action_check() {
  local MIN_FREE_GB="${1:-$DEFAULT_MIN_FREE_GB}"
  # Reject a bad threshold with "could not operate" (exit 2) rather than
  # letting the arithmetic below die on it and exit 1, which callers read as
  # "disk below threshold". Force base 10 afterwards: bash arithmetic reads
  # a leading zero ("08") as an invalid octal number and would die the same
  # wrong way on input the regex accepts.
  if [[ ! "$MIN_FREE_GB" =~ ^[0-9]+$ ]]; then
    echo "ERROR: the minimum free space threshold must be a whole number of GiB, got '${MIN_FREE_GB}'"
    return 2
  fi
  MIN_FREE_GB=$(( 10#$MIN_FREE_GB ))
  local MIN_FREE_BYTES=$(( MIN_FREE_GB * 1024 * 1024 * 1024 ))

  local GRAPHROOT FS_AVAIL
  if ! GRAPHROOT="$(graphroot)"; then
    echo "ERROR: podman is not functional (podman info failed): assuming storage maintenance is needed"
    return 2
  fi
  if ! FS_AVAIL=$(df -B1 --output=avail "$GRAPHROOT" | tail -1 | tr -d ' '); then
    echo "ERROR: cannot query free space on $GRAPHROOT: assuming storage maintenance is needed"
    return 2
  fi

  if (( FS_AVAIL >= MIN_FREE_BYTES )); then
    echo "OK: $(human "$FS_AVAIL") free on $GRAPHROOT (threshold: ${MIN_FREE_GB}GiB)"
    return 0
  fi
  echo "LOW: only $(human "$FS_AVAIL") free on $GRAPHROOT (threshold: ${MIN_FREE_GB}GiB)"
  return 1
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
  check)
    shift
    action_check "$@"
    ;;
  ""|-h|--help|help)
    cat <<EOF
Usage:
  $0 snapshot <output-file> <label>
  $0 compare  <beforereset.txt> <afterreset.txt> <afterbuild.txt>
  $0 check    [min-free-gb]   (default: ${DEFAULT_MIN_FREE_GB})
EOF
    [[ -z "$ACTION" ]] && exit 1 || exit 0
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    echo "Run '$0 --help' for usage." >&2
    exit 1
    ;;
esac
