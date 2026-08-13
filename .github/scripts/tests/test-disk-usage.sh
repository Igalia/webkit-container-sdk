#!/bin/bash
# Test harness for .github/scripts/disk-usage.sh: stubs podman/df/du via PATH
# and checks every action, exit code and degradation path. Run it directly;
# it needs no arguments and touches nothing outside a temp directory.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/disk-usage.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/graphroot" "$T/out"

# ---- stubs -------------------------------------------------------------
# podman stub: modes via PODMAN_MODE (normal | nounshare | broken | brokendf)
cat > "$T/bin/podman" <<STUB
#!/bin/bash
MODE="\${PODMAN_MODE:-normal}"
case "\$1" in
  info)
    [ "\$MODE" = broken ] && { echo "cannot connect to podman" >&2; exit 125; }
    echo "$T/graphroot"
    ;;
  unshare)
    [ "\$MODE" = nounshare ] && { echo "unshare failed" >&2; exit 1; }
    shift; exec "\$@"
    ;;
  system)
    [ "\$MODE" = brokendf ] && { echo "storage corrupted" >&2; exit 125; }
    echo "podman system df stub output"
    ;;
  *) echo "unexpected podman args: \$*" >&2; exit 1;;
esac
STUB
# df stub: DF_FAKE_AVAIL overrides avail (bytes); DF_H_FAIL=1 fails `df -h`
cat > "$T/bin/df" <<'STUB'
#!/bin/bash
if [ "${DF_H_FAIL:-}" = 1 ] && [ "$*" = "-h" ]; then echo "df: /deadmount: Transport endpoint is not connected" >&2; exit 1; fi
if [ -n "${DF_FAKE_AVAIL:-}" ]; then
  case "$*" in
    *--output=size,used,avail*) printf '1B-blocks Used Avail\n1000000000000 500000000000 %s\n' "$DF_FAKE_AVAIL"; exit 0;;
    *--output=avail*) printf 'Avail\n%s\n' "$DF_FAKE_AVAIL"; exit 0;;
  esac
fi
exec /usr/bin/df "$@"
STUB
# du stub: DU_FAKE_SIZE overrides, DU_FAIL=1 makes it fail; otherwise real du
cat > "$T/bin/du" <<'STUB'
#!/bin/bash
[ "${DU_FAIL:-}" = 1 ] && { echo "du failed" >&2; exit 1; }
[ "${DU_PARTIAL:-}" = 1 ] && { echo "du: cannot read directory: Permission denied" >&2; printf '%s\t%s\n' "12345" "${@: -1}"; exit 1; }
if [ -n "${DU_FAKE_SIZE:-}" ]; then printf '%s\t%s\n' "$DU_FAKE_SIZE" "${@: -1}"; exit 0; fi
exec /usr/bin/du "$@"
STUB
chmod +x "$T/bin/podman" "$T/bin/df" "$T/bin/du"
export PATH="$T/bin:$PATH"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "PASS: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
# assert <desc> <expected-exit|NZ> <grep-pattern|-> -- cmd...
assert() {
  local desc="$1" want_rc="$2" pat="$3"; shift 3; shift # eat --
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [ "$want_rc" = NZ ]; then
    [ "$rc" -ne 0 ] || { bad "$desc (exit 0, wanted non-zero) :: $out"; return; }
  elif [ "$rc" != "$want_rc" ]; then bad "$desc (exit $rc, wanted $want_rc) :: $out"; return; fi
  if [ "$pat" != "-" ] && ! grep -qE "$pat" <<<"$out"; then bad "$desc (missing /$pat/) :: $out"; return; fi
  ok "$desc"
}

GB=$((1024*1024*1024))

echo "=== main dispatch ==="
assert "no args -> usage, exit 1"            1 "Usage:" -- "$SCRIPT"
assert "--help -> usage, exit 0"             0 "Usage:" -- "$SCRIPT" --help
assert "-h -> usage, exit 0"                 0 "Usage:" -- "$SCRIPT" -h
assert "help -> usage, exit 0"               0 "Usage:" -- "$SCRIPT" help
assert "unknown action -> error, exit 1"     1 "Unknown action: frobnicate" -- "$SCRIPT" frobnicate

echo "=== check: thresholds and boundaries (stubbed df) ==="
export DF_FAKE_AVAIL=$((50*GB))
assert "avail == threshold (50GB) -> OK"     0 "^OK:" -- "$SCRIPT" check
export DF_FAKE_AVAIL=$((50*GB-1))
assert "avail == threshold-1 byte -> LOW"    1 "^LOW:" -- "$SCRIPT" check
export DF_FAKE_AVAIL=$((49*GB))
assert "explicit threshold 49 -> OK"         0 "^OK:" -- "$SCRIPT" check 49
assert "explicit threshold 50 -> LOW"        1 "^LOW:" -- "$SCRIPT" check 50
export DF_FAKE_AVAIL=0
assert "zero free -> LOW"                    1 "only 0.00B" -- "$SCRIPT" check
assert "non-numeric threshold -> cannot operate (exit 2)" 2 "must be a whole number" -- "$SCRIPT" check banana
assert "negative threshold -> cannot operate (exit 2)"    2 "must be a whole number" -- "$SCRIPT" check -5
assert "empty threshold falls back to the default"        1 "threshold: 50GiB" -- "$SCRIPT" check ""
assert "threshold 0 is valid (always OK)"                 0 "^OK:" -- "$SCRIPT" check 0
assert "leading zero read as decimal, not octal (08=8)"   1 "threshold: 8GiB" -- "$SCRIPT" check 08
assert "all-zeros threshold works (000=0)"                0 "^OK:.*threshold: 0GiB" -- "$SCRIPT" check 000
unset DF_FAKE_AVAIL

echo "=== snapshot: happy path (stubbed values) ==="
export DF_FAKE_AVAIL=$((100*GB)) DU_FAKE_SIZE=$((7*GB))
assert "snapshot runs"                       0 "FS_AVAIL=$((100*GB))" -- "$SCRIPT" snapshot "$T/out/s1.txt" "LABEL-1"
grep -q "PODMAN_SIZE=$((7*GB))" "$T/out/s1.txt" && ok "snapshot PODMAN_SIZE from podman-unshare du" || bad "snapshot PODMAN_SIZE wrong"
grep -q "GRAPHROOT=$T/graphroot" "$T/out/s1.txt" && ok "snapshot GRAPHROOT recorded" || bad "snapshot GRAPHROOT wrong"
grep -q "=== LABEL-1 (....-..-..T..:..:..Z) ===" "$T/out/s1.txt" && ok "snapshot label+timestamp" || bad "snapshot label/timestamp missing"
for key in FS_SIZE FS_USED FS_AVAIL PODMAN_SIZE; do
  v=$(grep -E "^$key=" "$T/out/s1.txt" | cut -d= -f2)
  [[ "$v" =~ ^[0-9]+$ ]] && ok "snapshot $key numeric ($v)" || bad "snapshot $key not numeric: '$v'"
done
[ ! -e "$T/out/s1.txt.tmp" ] && ok "no .tmp left after successful snapshot" || bad ".tmp leftover after success"
printf 'stale tmp junk' > "$T/out/s1.txt.tmp"
"$SCRIPT" snapshot "$T/out/s1.txt" "LABEL-1b" > /dev/null
[ ! -e "$T/out/s1.txt.tmp" ] && grep -q "LABEL-1b" "$T/out/s1.txt" && ok "stale .tmp cleaned and snapshot republished" || bad "stale .tmp handling broken"
assert "snapshot missing args -> usage, exit 1" 1 "Usage: .* snapshot" -- "$SCRIPT" snapshot
assert "snapshot unwritable output -> fails"    1 "-" -- "$SCRIPT" snapshot /nonexistent-dir/x.txt "L"

echo "=== snapshot: du fallback chain ==="
export PODMAN_MODE=nounshare
assert "unshare fails -> falls back to plain du" 0 "PODMAN_SIZE=$((7*GB))" -- "$SCRIPT" snapshot "$T/out/s2.txt" "L2"
export DU_FAIL=1
unset DU_FAKE_SIZE
assert "unshare and du both fail -> PODMAN_SIZE=unknown" 0 "PODMAN_SIZE=unknown" -- "$SCRIPT" snapshot "$T/out/s3.txt" "L3"
grep -q "  unknown" "$T/out/s3.txt" && ok "human-readable section shows unknown, not garbage" || bad "unknown not rendered plainly"
assert "compare with PODMAN_SIZE=unknown still reports FS numbers" 0 "Net space freed" -- "$SCRIPT" compare "$T/out/s3.txt" "$T/out/s2.txt" "$T/out/s2.txt"
OUT=$("$SCRIPT" compare "$T/out/s3.txt" "$T/out/s2.txt" "$T/out/s2.txt")
grep -qF "not measured" <<<"$OUT" && ok "podman deltas degrade to 'not measured'" || bad "podman deltas not degraded"
grep -qE "Removed by reset .*not measured" <<<"$OUT" && ok "podman delta line degraded, not omitted" || bad "podman delta line wrong"
grep -qF "could not measure the podman storage size" <<<"$OUT" && ok "warning explains the degradation" || bad "degradation warning missing"
unset DU_FAIL PODMAN_MODE

echo "=== partial du (prints an undercount, exits non-zero) ==="
export PODMAN_MODE=nounshare DU_PARTIAL=1
assert "partial du -> PODMAN_SIZE=unknown (not the undercount)" 0 "PODMAN_SIZE=unknown" -- "$SCRIPT" snapshot "$T/out/s8.txt" "L8"
grep -q "PODMAN_SIZE=12345" "$T/out/s8.txt" && bad "undercounted du total was recorded" || ok "undercounted total rejected"
unset DU_PARTIAL PODMAN_MODE
export DU_FAKE_SIZE=$((7*GB))

echo "=== broken podman (storage so corrupted that podman itself fails) ==="
export PODMAN_MODE=broken
assert "check with broken podman -> exit 2 + meaningful error" 2 "ERROR: podman is not functional" -- "$SCRIPT" check
printf 'stale data from a previous run\n' > "$T/out/s4.txt"
assert "snapshot with broken podman -> exit 2 + warning" 2 "warning: podman is not functional" -- "$SCRIPT" snapshot "$T/out/s4.txt" "L4"
[ ! -e "$T/out/s4.txt" ] && ok "snapshot removed the stale file and wrote nothing" || bad "stale snapshot file left behind"
export PODMAN_MODE=brokendf
assert "snapshot survives 'podman system df' failing" 0 "FS_AVAIL=" -- "$SCRIPT" snapshot "$T/out/s5.txt" "L5"
grep -q "(podman system df failed)" "$T/out/s5.txt" && ok "system-df failure noted inside snapshot" || bad "system-df failure not noted"
grep -qE "^FS_AVAIL=[0-9]+" "$T/out/s5.txt" && ok "partial-podman snapshot still valid for compare" || bad "partial snapshot lacks FS_AVAIL"
unset PODMAN_MODE

echo "=== dead unrelated mount: df -h fails but snapshot survives ==="
export DF_H_FAIL=1
assert "snapshot survives df -h failure" 0 "FS_AVAIL=" -- "$SCRIPT" snapshot "$T/out/s7.txt" "L7"
grep -q "(df -h failed" "$T/out/s7.txt" && ok "df -h failure noted in snapshot" || bad "df -h failure not noted"
grep -qE "^PODMAN_SIZE=[0-9]+" "$T/out/s7.txt" && ok "df-h-fail snapshot still valid for compare" || bad "df-h-fail snapshot invalid"
unset DF_H_FAIL

echo "=== compare: exact math end-to-end via generated snapshots ==="
gen() { # avail-gb podman-gb outfile
  DF_FAKE_AVAIL=$(( $1*GB )) DU_FAKE_SIZE=$(( $2*GB )) "$SCRIPT" snapshot "$3" "GEN" > /dev/null
}
gen 100 500 "$T/out/before.txt"
gen 580  20 "$T/out/afterreset.txt"
gen 430 170 "$T/out/afterbuild.txt"
OUT=$("$SCRIPT" compare "$T/out/before.txt" "$T/out/afterreset.txt" "$T/out/afterbuild.txt") || bad "compare exited non-zero"
expect() { grep -qF "$2" <<<"$OUT" && ok "compare: $1" || bad "compare: $1 (wanted '$2')"; }
expect "net freed = 330GB"          "330.00GiB"
expect "build cost = 150GB"         "150.00GiB"
expect "removed by reset = 480GB"   "Removed by reset (BeforeReset - AfterReset):  480.00GiB"
expect "net podman change = -330GB" "Net change      (AfterBuild - BeforeReset):   -330.00GiB"
grep -qE "Before reset: +100.00GiB" <<<"$OUT" && ok "compare: before-reset avail 100GB" || bad "compare: before-reset avail"

echo "=== compare: negative freed (build bigger than what reset freed) ==="
gen 100 100 "$T/out/n1.txt"; gen 120 10 "$T/out/n2.txt"; gen 90 40 "$T/out/n3.txt"
OUT=$("$SCRIPT" compare "$T/out/n1.txt" "$T/out/n2.txt" "$T/out/n3.txt")
grep -qF -- "-10.00GiB" <<<"$OUT" && ok "negative delta rendered with sign" || bad "negative delta rendering"

echo "=== compare: GITHUB_STEP_SUMMARY markdown ==="
export GITHUB_STEP_SUMMARY="$T/out/summary.md"; : > "$GITHUB_STEP_SUMMARY"
"$SCRIPT" compare "$T/out/before.txt" "$T/out/afterreset.txt" "$T/out/afterbuild.txt" > /dev/null
grep -qF "| Net space freed (AfterBuild - BeforeReset) | 330.00GiB |" "$GITHUB_STEP_SUMMARY" && ok "markdown table row correct" || bad "markdown table row"
grep -qF "## Podman storage maintenance summary" "$GITHUB_STEP_SUMMARY" && ok "markdown header present" || bad "markdown header"
unset GITHUB_STEP_SUMMARY
rm -f "$T/out/summary.md"
"$SCRIPT" compare "$T/out/before.txt" "$T/out/afterreset.txt" "$T/out/afterbuild.txt" > /dev/null
[ ! -e "$T/out/summary.md" ] && ok "no summary file written when env unset" || bad "summary written without env"

echo "=== compare: degradation is per-delta and keeps measured values ==="
gen 100 500 "$T/out/g_r.txt"; gen 430 170 "$T/out/g_x.txt"
printf 'FS_AVAIL=%s\nPODMAN_SIZE=unknown\n' $((100*GB)) > "$T/out/g_b.txt"
OUT=$("$SCRIPT" compare "$T/out/g_b.txt" "$T/out/g_r.txt" "$T/out/g_x.txt"); rc=$?
[ "$rc" = 0 ] && ok "degraded compare still exits 0" || bad "degraded compare exit $rc"
grep -qE "Added by build .*[0-9]+\.[0-9]+.iB" <<<"$OUT" && ok "computable delta keeps a real number" || bad "computable delta was blanked"
grep -qE "Removed by reset .*not measured" <<<"$OUT" && ok "affected delta says not measured" || bad "affected delta not degraded"
grep -qE "After  reset: +[0-9]+\.[0-9]+.iB" <<<"$OUT" && ok "measured sizes still shown" || bad "measured sizes were blanked"
grep -qE "Before reset: +not measured" <<<"$OUT" && ok "unmeasured size labelled consistently" || bad "unmeasured size wording"
printf 'FS_AVAIL=%s\nPODMAN_SIZE=abc\n' $((100*GB)) > "$T/out/g_bad.txt"
assert "garbage PODMAN_SIZE -> skip, exit 2 (malformed, not degraded)" 2 "skipping comparison" -- "$SCRIPT" compare "$T/out/g_bad.txt" "$T/out/g_r.txt" "$T/out/g_x.txt"

echo "=== compare: degraded podman metrics reach the step summary ==="
export GITHUB_STEP_SUMMARY="$T/out/degsum.md"; : > "$GITHUB_STEP_SUMMARY"
"$SCRIPT" compare "$T/out/s3.txt" "$T/out/s2.txt" "$T/out/s2.txt" > /dev/null
grep -qF "| Removed by reset (BeforeReset - AfterReset) | not measured |" "$GITHUB_STEP_SUMMARY" && ok "markdown shows 'not measured'" || bad "markdown degradation missing"
grep -qE "^\| Net space freed .* \| -?[0-9.]+[KMGT]?i?B \|$" "$GITHUB_STEP_SUMMARY" && ok "markdown still reports FS metric" || bad "markdown lost FS metric"
unset GITHUB_STEP_SUMMARY

echo "=== compare: bad inputs ==="
assert "compare missing 3rd arg -> usage, exit 1" 1 "Usage: .* compare" -- "$SCRIPT" compare "$T/out/before.txt" "$T/out/afterreset.txt"
assert "compare with missing file -> skips, exit 2" 2 "skipping comparison" -- "$SCRIPT" compare /nope1 /nope2 /nope3
printf 'GARBAGE\n' > "$T/out/malformed.txt"
assert "compare with malformed snapshot -> skips, exit 2" 2 "skipping comparison" -- "$SCRIPT" compare "$T/out/malformed.txt" "$T/out/afterreset.txt" "$T/out/afterbuild.txt"
printf 'FS_AVAIL=notanumber\nPODMAN_SIZE=123\n' > "$T/out/badnum.txt"
assert "compare with non-numeric FS_AVAIL -> skips, exit 2" 2 "skipping comparison" -- "$SCRIPT" compare "$T/out/badnum.txt" "$T/out/afterreset.txt" "$T/out/afterbuild.txt"
printf 'FS_AVAIL=123abc\nPODMAN_SIZE=123\n' > "$T/out/trailing.txt"
assert "compare with trailing-garbage FS_AVAIL -> skips, exit 2" 2 "skipping comparison" -- "$SCRIPT" compare "$T/out/trailing.txt" "$T/out/afterreset.txt" "$T/out/afterbuild.txt"
printf 'FS_AVAIL=1\nFS_AVAIL=2\nPODMAN_SIZE=3\n' > "$T/out/dup.txt"
assert "compare with duplicated FS_AVAIL -> skips, exit 2" 2 "skipping comparison" -- "$SCRIPT" compare "$T/out/dup.txt" "$T/out/afterreset.txt" "$T/out/afterbuild.txt"
OUT=$("$SCRIPT" compare "$T/out/before.txt" "$T/out/afterreset.txt" "$T/out/afterbuild.txt")
grep -qF "330.00GiB" <<<"$OUT" && ok "valid files still compared after guard added" || bad "guard broke the happy path"
export GITHUB_STEP_SUMMARY="$T/out/skipsum.md"; : > "$GITHUB_STEP_SUMMARY"
"$SCRIPT" compare /nope1 /nope2 /nope3 > /dev/null || true
grep -qF "Comparison skipped" "$GITHUB_STEP_SUMMARY" && ok "skip note written to step summary" || bad "skip note missing from step summary"
unset GITHUB_STEP_SUMMARY

echo "=== human(): numfmt-missing fallback ==="
mkdir -p "$T/nofmt"
for tool in bash grep head tail cut awk tee date tr cat sed; do ln -sf "$(command -v $tool)" "$T/nofmt/"; done
ln -sf "$T/bin/podman" "$T/bin/df" "$T/bin/du" "$T/nofmt/"
OUT=$(PATH="$T/nofmt" DF_FAKE_AVAIL=$((60*GB)) "$SCRIPT" check) && \
  grep -qF "$((60*GB)) bytes" <<<"$OUT" && ok "no numfmt -> raw bytes fallback" || bad "no-numfmt fallback :: $OUT"

echo "=== graphroot path with spaces ==="
mkdir -p "$T/graph root with spaces"
sed "s|$T/graphroot|$T/graph root with spaces|" "$T/bin/podman" > "$T/bin/podman.tmp" && mv "$T/bin/podman.tmp" "$T/bin/podman" && chmod +x "$T/bin/podman"
assert "snapshot with spaces in graphroot" 0 "GRAPHROOT=$T/graph root with spaces" -- env DF_FAKE_AVAIL=$((100*GB)) DU_FAKE_SIZE=$((7*GB)) "$SCRIPT" snapshot "$T/out/s6.txt" "L6"
assert "check with spaces in graphroot"    0 "^OK:" -- env DF_FAKE_AVAIL=$((100*GB)) "$SCRIPT" check

echo
echo "================================"
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
