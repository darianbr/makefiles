#!/usr/bin/env bash
set -euo pipefail
unset MAKEFLAGS GNUMAKEFLAGS MF_LEGACY_GOALS MF_SCOPED_MODULE

repo=$(cd "$(dirname "$0")/.." && pwd -P)
make_bin=${MAKE_BIN:-make}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/remote" "$tmp/project"
cp -R "$repo/modules/." "$tmp/remote/"
cp "$repo/fetch" "$tmp/remote/fetch"

# Simulate the published site without network access. The shim serves both
# `curl -o <file>` (fetch) and bare `curl` (bootstrap pipe to bash).
cat > "$tmp/bin/curl" <<'SH'
#!/bin/sh
set -eu
[ "${FAIL_ALL:-0}" = 1 ] && exit 7
url=; out=
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    --max-time|--connect-timeout) shift 2 ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done
# Module files live under /modules/; the fetch script lives at the site root.
# Log the site-root-relative path (keeping modules/) for assertions, but look
# up the file with modules/ stripped since $REMOTE is rooted at modules/.
case "$url" in https://test.invalid/*) ;; *) echo "invalid URL: $url" >&2; exit 3 ;; esac
path=${url#https://test.invalid/}
file=${path#modules/}
printf '%s\n' "$path" >> "$CURL_LOG"
[ "$path" != "${FAIL_PATH:-}" ] || exit 22
if [ -n "$out" ]; then cp "$REMOTE/$file" "$out"; else cat "$REMOTE/$file"; fi
SH
chmod +x "$tmp/bin/curl"
export REMOTE="$tmp/remote" CURL_LOG="$tmp/curl.log"
export PATH="$tmp/bin:$PATH" MAKEFILES_BASE_URL=https://test.invalid/modules
: > "$CURL_LOG"

fail() { echo "FAIL: $*" >&2; exit 1; }
cd "$tmp/project"
cat > Makefile <<'EOF'
-include .makefiles/modules/wtree/Makefile
.makefiles/modules/%/Makefile:
EOF
printf '\t%s\n' 'curl -sf "https://test.invalid/fetch" | bash /dev/stdin $*' >> Makefile

# 1. Corruption self-heal: a damaged cached file is re-fetched and restored.
# This test covers parseable damage only. Make parses included files before
# recipes, so it does not demonstrate recovery from malformed make syntax.
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'initial bootstrap + scoped help'; }
grep -F 'Available targets:' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'scoped help output'; }
test -f .makefiles/modules/.manifest.sha256 || fail 'hash record missing after fetch'
# Adding a private verification target must not change the default goal.
mkdir "$tmp/bare-project"
cp -R .makefiles "$tmp/bare-project/"
printf '%s\n' 'include .makefiles/modules/wtree/Makefile' > "$tmp/bare-project/Makefile"
(cd "$tmp/bare-project" && "$make_bin" --no-print-directory -n > "$tmp/bare.out" 2>&1) || { cat "$tmp/bare.out" >&2; fail 'bare make changed its default goal'; }
grep -F '[base] clean makefiles folder' "$tmp/bare.out" >/dev/null || { cat "$tmp/bare.out" >&2; fail 'bare make did not select the original clean goal'; }
# Removing just one checksum must not hide damage to that file.
awk '$2 != "wtree/targets.mk"' .makefiles/modules/.manifest.sha256 > "$tmp/partial-record"
cp "$tmp/partial-record" .makefiles/modules/.manifest.sha256
printf '\nCORRUPTED=1\n' >> .makefiles/modules/wtree/targets.mk
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'partial hash record did not self-heal'; }
cmp "$repo/modules/wtree/targets.mk" .makefiles/modules/wtree/targets.mk || fail 'partial hash record concealed corruption'
# Each required shared record must exist exactly once, and a missing manifest
# must also trigger recovery rather than being mistaken for a local-only module.
for path in VERSION manifest.txt; do
  awk -v path="$path" '$2 != path' .makefiles/modules/.manifest.sha256 > "$tmp/partial-record"
  cp "$tmp/partial-record" .makefiles/modules/.manifest.sha256
  "$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail "missing $path hash did not self-heal"; }
  test "$(awk -v path="$path" '$2 == path { n++ } END { print n+0 }' .makefiles/modules/.manifest.sha256)" -eq 1 || fail "missing $path hash was not restored"
done
awk '$2 == "wtree/targets.mk" { print }' .makefiles/modules/.manifest.sha256 >> "$tmp/duplicate-record"
cat "$tmp/duplicate-record" >> .makefiles/modules/.manifest.sha256
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'duplicate hash did not self-heal'; }
test "$(awk '$2 == "wtree/targets.mk" { n++ } END { print n+0 }' .makefiles/modules/.manifest.sha256)" -eq 1 || fail 'duplicate hash was not removed'
rm .makefiles/modules/manifest.txt
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'missing manifest did not self-heal'; }
cmp "$repo/modules/manifest.txt" .makefiles/modules/manifest.txt || fail 'missing manifest was not restored'
# A modified manifest must not turn a published module into a local-only one.
awk 'index($0, "wtree/") != 1' .makefiles/modules/manifest.txt > "$tmp/partial-manifest"
cp "$tmp/partial-manifest" .makefiles/modules/manifest.txt
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'damaged manifest did not self-heal'; }
cmp "$repo/modules/manifest.txt" .makefiles/modules/manifest.txt || fail 'damaged manifest concealed a published module'
printf '\nCORRUPTED=1\n' >> .makefiles/modules/wtree/targets.mk
: > "$CURL_LOG"
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'corrupted cache did not self-heal'; }
cmp "$repo/modules/wtree/targets.mk" .makefiles/modules/wtree/targets.mk || fail 'corrupted file was not restored'
grep -F 'modules/wtree/targets.mk' "$CURL_LOG" >/dev/null || fail 'self-heal did not re-fetch the corrupted module file'

# 2. Missing record: a deleted hash file triggers one re-fetch, then is quiet.
rm .makefiles/modules/.manifest.sha256
: > "$CURL_LOG"
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'missing record did not self-heal'; }
test -f .makefiles/modules/.manifest.sha256 || fail 'hash record was not recreated'
: > "$CURL_LOG"
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'healthy cache failed'; }
test ! -s "$CURL_LOG" || fail 'healthy cache made network calls'

# 3. Offline failure: corruption + dead network fails fast and names the file.
printf '\nCORRUPTED=1\n' >> .makefiles/modules/wtree/targets.mk
# Python is available on both CI platforms, unlike GNU timeout on macOS.
# Kill the whole process group if Make or one of its children hangs.
rc=0
FAIL_ALL=1 python3 -c '
import os, signal, subprocess, sys
process = subprocess.Popen(sys.argv[1:], start_new_session=True)
try:
    sys.exit(process.wait(timeout=30))
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGKILL)
    process.wait()
    print("offline verification timed out", file=sys.stderr)
    sys.exit(124)
' "$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || rc=$?
if [ "$rc" -eq 124 ]; then
  cat "$tmp/out" >&2
  fail 'offline verification timed out'
fi
if [ "$rc" -eq 0 ]; then
  fail 'offline corruption was accepted'
fi
grep -F 'wtree/targets.mk' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'offline failure did not name the corrupted file'; }
grep -F "cache verification failed for wtree/targets.mk in module 'wtree'" "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'offline failure message'; }
# The re-fetch must have been attempted (bounded curl) and not looped.
grep -c 're-fetching' "$tmp/out" | grep -qx 1 || { cat "$tmp/out" >&2; fail 'self-heal looped or did not attempt a re-fetch'; }
# The cache is left intact (still corrupted, but not half-replaced).
grep -q 'CORRUPTED=1' .makefiles/modules/wtree/targets.mk || fail 'failed re-fetch damaged the cache further'

# 4. An upgraded cache with a missing record self-heals once, then is quiet.
# This is not a pre-upgrade cache: old code cannot invoke the new verifier.
rm .makefiles/modules/.manifest.sha256
: > "$CURL_LOG"
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'legacy cache first run'; }
test -f .makefiles/modules/.manifest.sha256 || fail 'legacy cache did not gain a hash record'
: > "$CURL_LOG"
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'legacy cache second run'; }
test ! -s "$CURL_LOG" || fail 'legacy cache made network calls after self-heal'

# 5. Aggregate mode verifies every imported module, healing only the broken one.
mkdir -p .makefiles/modules/other
cat > .makefiles/modules/other/Makefile <<'EOF'
-include .makefiles/modules/Makefile
MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/other/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),clean install help status))
.PHONY: status
status::
	@echo other-status
EOF
# Import a second published module (phpunit) so aggregate verification covers
# more than wtree; the corruption must stay parseable make syntax.
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'second module fetch'; }
bash "$repo/fetch" phpunit > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'phpunit fetch'; }
printf '%s\n' 'include .makefiles/modules/wtree/Makefile' 'include .makefiles/modules/other/Makefile' 'include .makefiles/modules/phpunit/Makefile' > Makefile
printf '\nCORRUPTED=1\n' >> .makefiles/modules/phpunit/targets.mk
# wtree status provisions a release binary; pre-install a fake one so the
# aggregate run stays focused on cache verification, not binary download.
mkdir -p .makefiles/tools
cat > .makefiles/tools/wtree-fake <<'EOF'
#!/bin/sh
echo wtree-status
EOF
chmod +x .makefiles/tools/wtree-fake
: > "$CURL_LOG"
WTREE_BIN="$PWD/.makefiles/tools/wtree-fake" "$make_bin" --no-print-directory status > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'aggregate status with corrupted module'; }
grep -F 'other-status' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'aggregate status output'; }
cmp "$repo/modules/phpunit/targets.mk" .makefiles/modules/phpunit/targets.mk || fail 'aggregate heal did not restore the corrupted module file'
grep -F 'modules/phpunit/targets.mk' "$CURL_LOG" >/dev/null || fail 'aggregate heal did not re-fetch the corrupted module file'

# 6. modules-version is local-only; modules-update is explicit and prints old -> new.
: > "$CURL_LOG"
"$make_bin" --no-print-directory modules-version > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'modules-version'; }
grep -F '0.2.0' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'modules-version did not print the recorded VERSION'; }
grep -Eq '[0-9a-f]{12}' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'modules-version did not print a 12-char manifest hash'; }
test ! -s "$CURL_LOG" || fail 'modules-version made network calls'
printf '0.3.0\n' > "$REMOTE/VERSION"
: > "$CURL_LOG"
"$make_bin" --no-print-directory modules-update > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'modules-update'; }
grep -F '0.2.0 -> 0.3.0' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'modules-update did not print old -> new'; }
test "$(cat .makefiles/modules/VERSION)" = "0.3.0" || fail 'modules-update did not refresh the cached VERSION'
"$make_bin" --no-print-directory modules-version > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'modules-version after update'; }
grep -F '0.3.0' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'modules-version did not reflect the update'; }
if FAIL_ALL=1 "$make_bin" --no-print-directory modules-update > "$tmp/out" 2>&1; then
  fail 'offline modules-update reported success'
fi

# 7. A normal build never re-fetches because the site is newer (updates stay explicit).
printf '0.4.0\n' > "$REMOTE/VERSION"
: > "$CURL_LOG"
"$make_bin" --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'scoped build with newer site VERSION'; }
grep -F 'Available targets:' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'scoped build output'; }
if grep -F 'modules/' "$CURL_LOG" >/dev/null; then
  echo "FAIL: normal build re-fetched module files (silent update):" >&2
  cat "$CURL_LOG" >&2
  exit 1
fi

# 8. Direct -f usage of a module entry point is also protected by the hash check.
printf '%s\n' '-include .makefiles/modules/wtree/Makefile' > Makefile
printf '\nCORRUPTED=1\n' >> .makefiles/modules/wtree/targets.mk
: > "$CURL_LOG"
WTREE_BIN="$PWD/.makefiles/tools/wtree-fake" "$make_bin" --no-print-directory -f .makefiles/modules/wtree/Makefile mf-wtree-ensure > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'direct -f ensure with corrupted cache'; }
cmp "$repo/modules/wtree/targets.mk" .makefiles/modules/wtree/targets.mk || fail 'direct -f ensure did not restore the corrupted file'

echo 'verify-cache tests passed'
