#!/bin/bash
# Test harness for .github/scripts/assert-runner-in-maintenance-matrix.sh:
# exercises every YAML spelling the parser supports, every rejection, and
# the exit-code contract (0 = covered, 1 = not covered, 2 = cannot tell).
# Run it directly; it needs no arguments and touches nothing outside a temp
# directory. It ends by checking the real maintenance matrix of this repo.
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/assert-runner-in-maintenance-matrix.sh"
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

PASS=0; FAIL=0
# t <description> <runner-name> <expected-exit-code>
# The script under test reads .github/workflows/podman-storage-maintenance.yaml
# relative to the current directory.
t() {
  local rc=0 out
  out=$(RUNNER_NAME="$2" "$SCRIPT" 2>&1) || rc=$?
  if [ "$rc" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"
  else FAIL=$((FAIL+1)); echo "FAIL: $1 (exit $rc, wanted $3) :: $out"; fi
}
matrix() { # write a matrix with the given entry lines to the temp workdir
  mkdir -p "$T/work/.github/workflows"
  printf 'jobs:\n  system-reset-and-rebuild:\n    strategy:\n      matrix:\n        include:\n%s\n    runs-on: self-hosted\n' "$1" \
    > "$T/work/.github/workflows/podman-storage-maintenance.yaml"
  cd "$T/work"
}

echo "=== every supported spelling matches ==="
matrix '          - arch: amd64
            runner: plain-1
          - runner: "quoted-2"
          - runner: '\''squoted-3'\''
          - runner: name with spaces 4
          - runner: commented-5   # rack 3
          - runner: "quoted-commented-6"   # rack 4
          - runner: -dash-leading-7
          - arch: amd64
            runner : spaced-key-8
          - runner: plain#hash
          - runner: "quoted#hash"
          # - runner: decommissioned-9'
t "plain entry"                      "plain-1" 0
t "double-quoted entry"              "quoted-2" 0
t "single-quoted entry"              "squoted-3" 0
t "name with spaces"                 "name with spaces 4" 0
t "trailing comment"                 "commented-5" 0
t "quoted + trailing comment"        "quoted-commented-6" 0
t "name starting with a dash"        "-dash-leading-7" 0
t "space before the colon"           "spaced-key-8" 0
t "hash in a plain name"             "plain#hash" 0
t "hash in a quoted name"            "quoted#hash" 0

echo "=== what must NOT match ==="
t "commented-out entry"              "decommissioned-9" 1
t "absent name"                      "not-listed" 1
t "prefix of a listed name"          "plain" 1
t "superstring of a listed name"     "plain-11" 1
t "regex metacharacters stay literal" "plain-." 1
t "quotes are not part of the name"  "\"quoted-2\"" 1
t "hash suffix is not discarded"     "plain" 1

echo "=== entries outside the maintenance matrix are ignored ==="
matrix '          - runner: maintenance-10'
printf '  unrelated-job:\n    strategy:\n      matrix:\n        runner: unrelated-11\n' \
  >> "$T/work/.github/workflows/podman-storage-maintenance.yaml"
t "maintenance runner remains covered"  "maintenance-10" 0
t "runner from another job is not covered" "unrelated-11" 1

echo "=== unreadable matrices are exit 2, never a wrong answer ==="
matrix '          - runner: "unclosed-12'
t "unclosed quote"                   "unclosed-12" 2
matrix '          - runner: "hash # inside 13"'
t "hash inside a quoted name"        "hash # inside 13" 2
matrix "          - runner: o'brien-14"
t "quote character inside a name"    "o'brien-14" 2
matrix '          - arch: amd64
            runner: block-15
          - {arch: arm64, runner: flow-16}'
t "flow-style entry present: flow name"  "flow-16" 2
t "flow-style entry present: block name" "block-15" 2
matrix '          - runner: plain-17
          # - {arch: amd64, runner: dead-flow-18}'
t "commented-out flow entry is ignored"  "plain-17" 0
t "commented-out flow name not covered"  "dead-flow-18" 1
matrix '          - {arch: amd64, runner: flow-only-19}'
t "flow-only matrix"                     "flow-only-19" 2
mkdir -p "$T/work/.github/workflows"
printf 'jobs:\n  system-reset-and-rebuild:\n    strategy:\n      matrix:\n        include: [{arch: amd64, runner: inline-20}]\n          # a block entry elsewhere must not mask the inline one:\n      other:\n        runner: block-21\n    runs-on: self-hosted\n' \
  > "$T/work/.github/workflows/podman-storage-maintenance.yaml"
cd "$T/work"
t "inline-array flow entry detected"     "inline-20" 2
matrix '          - arch: amd64'
t "matrix without runner entries"    "anything" 2
cd "$T"
rm -rf "$T/work"
mkdir -p "$T/work" && cd "$T/work"
t "workflow file missing"            "anything" 2

echo "=== the real matrix of this repository ==="
cd "$REPO_ROOT"
REAL_MATRIX=".github/workflows/podman-storage-maintenance.yaml"
# The real matrix keeps its entries in the plain `runner: <name>` form, so
# this trivial awk is a fair independent oracle for what must be covered.
REAL_RUNNERS=$(awk '$1 == "runner:" {print $2}' "$REAL_MATRIX")
if [ -z "$REAL_RUNNERS" ]; then
  FAIL=$((FAIL+1)); echo "FAIL: no plain runner: entries found in $REAL_MATRIX"
fi
while IFS= read -r name; do
  t "real matrix entry: $name" "$name" 0
done <<<"$REAL_RUNNERS"
t "name absent from the real matrix" "no-such-runner-anywhere" 1

echo
echo "================================"
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
