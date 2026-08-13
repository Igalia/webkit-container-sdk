#!/bin/bash
# Fails (exit 1) when the runner executing this job is not listed in the
# podman-storage-maintenance.yaml matrix. The matrix entries are runner
# names (used as unique labels), so a runner missing from that list never
# gets its storage reset and would silently fill up its disk.
#
# Expects RUNNER_NAME in the environment (the workflow passes runner.name).
# The match is an exact whole-string comparison against every `runner:` value
# of the matrix, so a runner name is never treated as a pattern (no false
# match) and quoted entries, names containing spaces or a trailing comment on
# the matrix line are all handled (no false "not covered" failure).
#
# Exits 2 when the matrix itself cannot be read: no entries at all, a
# flow-style entry ({arch: ..., runner: ...}), or an entry this script
# cannot parse (unclosed quote, a comment-like '#' inside a quoted name, or
# a quote character anywhere in a name). Those get their own error, because
# "I cannot tell" and "this runner is not covered" call for different fixes.

set -euo pipefail

RUNNER_NAME="${RUNNER_NAME:?RUNNER_NAME must be set to runner.name}"
MAINTENANCE_WORKFLOW=".github/workflows/podman-storage-maintenance.yaml"

if [[ ! -f "$MAINTENANCE_WORKFLOW" ]]; then
  echo "error: ${MAINTENANCE_WORKFLOW} not found (not running from the repository root?): cannot audit" >&2
  exit 2
fi

# Limit all parsing to the matrix of the maintenance job. A `runner:` key in
# another job must never make this audit claim that the machine is covered.
job_block=$(sed -n '/^  system-reset-and-rebuild:/,/^  [^ ]/p' "$MAINTENANCE_WORKFLOW")
matrix_block=$(sed -n '/^      matrix:/,/^    [^ ]/p' <<<"$job_block")

# A flow-style entry ({arch: ..., runner: ...}) is invisible to the
# extraction below, so its runner would be reported as "not covered" even
# though the maintenance job does reach it. Refuse to answer instead.
flow_entries=$(sed -n -e '/^[[:space:]]*#/d' \
                      -e '/{[^}]*runner[[:space:]]*:/{s/^[[:space:]]*//p}' \
                      <<<"$matrix_block")
if [[ -n "$flow_entries" ]]; then
  echo "::error title=Unparseable runner entry in the maintenance matrix::Cannot read these flow-style entries of ${MAINTENANCE_WORKFLOW}: ${flow_entries//$'\n'/, }. Write each matrix entry in block form, with 'runner: <name>' on its own line."
  exit 2
fi

# Every `runner:` value of the matrix, one per line: commented-out entries are
# ignored, then each value has its trailing comment, trailing whitespace and
# surrounding quotes removed.
covered_runners=$(
  sed -n -e '/^[[:space:]]*#/d' \
         -e 's/^[[:space:]]*-\{0,1\}[[:space:]]*runner[[:space:]]*:[[:space:]]*//p' \
         <<<"$matrix_block" \
    | sed -e 's/[[:space:]][[:space:]]*#.*$//' -e 's/[[:space:]]*$//' \
          -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
)

if [[ -z "$covered_runners" ]]; then
  echo "::error title=No runner entries in the maintenance matrix::${MAINTENANCE_WORKFLOW} has no 'runner:' entry, so this audit cannot tell whether this machine is covered."
  exit 2
fi

# A value that still carries a quote was not parsed as intended: an unclosed
# quote, a whitespace-prefixed '#' inside a quoted name (taken for a trailing
# comment above), or a quote character that is part of the name itself.
# Report that instead of answering the coverage question wrongly.
if unparseable=$(grep -F -e '"' -e "'" <<<"$covered_runners"); then
  echo "::error title=Unparseable runner entry in the maintenance matrix::Cannot read these runner entries of ${MAINTENANCE_WORKFLOW}: ${unparseable//$'\n'/, }. Write each one as a plain or fully quoted scalar, without a whitespace-prefixed '#' inside the name."
  exit 2
fi

# -x -F: whole-line literal match, so no character of the name is special.
# -e: a name starting with '-' must not be taken for a grep option.
if grep -qxF -e "$RUNNER_NAME" <<<"$covered_runners"; then
  echo "Runner '${RUNNER_NAME}' is covered by the storage maintenance workflow."
else
  echo "::error title=Runner not covered by storage maintenance::Runner '${RUNNER_NAME}' is not listed in the ${MAINTENANCE_WORKFLOW} matrix, so its storage is never reset. Add the runner's name as a label to it in the GitHub UI and add a matrix entry."
  exit 1
fi
