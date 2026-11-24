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
# The corruption must stay parseable make syntax: files the build includes are
# parsed before any recipe runs, so syntax-level damage of an included file is
# outside make's self-heal scope (recovery is `make clean`). fetch's atomic
# staging means real truncation cannot occur, so content-level damage is the
# threat model.
make --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'initial bootstrap + scoped help'; }
grep -F 'Available targets:' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'scoped help output'; }
test -f .makefiles/modules/.manifest.sha256 || fail 'hash record missing after fetch'
printf '\nCORRUPTED=1\n' >> .makefiles/modules/wtree/targets.mk
: > "$CURL_LOG"
make --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'corrupted cache did not self-heal'; }
cmp "$repo/modules/wtree/targets.mk" .makefiles/modules/wtree/targets.mk || fail 'corrupted file was not restored'
grep -F 'modules/wtree/targets.mk' "$CURL_LOG" >/dev/null || fail 'self-heal did not re-fetch the corrupted module file'

# 2. Missing record: a deleted hash file triggers one re-fetch, then is quiet.
rm .makefiles/modules/.manifest.sha256
: > "$CURL_LOG"
make --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'missing record did not self-heal'; }
test -f .makefiles/modules/.manifest.sha256 || fail 'hash record was not recreated'
: > "$CURL_LOG"
make --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'healthy cache failed'; }
test ! -s "$CURL_LOG" || fail 'healthy cache made network calls'

# 3. Offline failure: corruption + dead network fails fast and names the file.
printf '\nCORRUPTED=1\n' >> .makefiles/modules/wtree/targets.mk
if FAIL_ALL=1 timeout 30 make --no-print-directory wtree help > "$tmp/out" 2>&1; then
  fail 'offline corruption was accepted'
fi
grep -F 'wtree/targets.mk' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'offline failure did not name the corrupted file'; }
grep -F "cache verification failed for wtree/targets.mk in module 'wtree'" "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'offline failure message'; }
# The re-fetch must have been attempted (bounded curl) and not looped.
grep -c 're-fetching' "$tmp/out" | grep -qx 1 || { cat "$tmp/out" >&2; fail 'self-heal looped or did not attempt a re-fetch'; }
# The cache is left intact (still corrupted, but not half-replaced).
grep -q 'CORRUPTED=1' .makefiles/modules/wtree/targets.mk || fail 'failed re-fetch damaged the cache further'

# 4. Legacy cache: a pre-hash consumer self-heals once, then is quiet.
rm .makefiles/modules/.manifest.sha256
: > "$CURL_LOG"
make --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'legacy cache first run'; }
test -f .makefiles/modules/.manifest.sha256 || fail 'legacy cache did not gain a hash record'
: > "$CURL_LOG"
make --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'legacy cache second run'; }
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
make --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'second module fetch'; }
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
WTREE_BIN="$PWD/.makefiles/tools/wtree-fake" make --no-print-directory status > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'aggregate status with corrupted module'; }
grep -F 'other-status' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'aggregate status output'; }
cmp "$repo/modules/phpunit/targets.mk" .makefiles/modules/phpunit/targets.mk || fail 'aggregate heal did not restore the corrupted module file'
grep -F 'modules/phpunit/targets.mk' "$CURL_LOG" >/dev/null || fail 'aggregate heal did not re-fetch the corrupted module file'

# 6. modules-version is local-only; modules-update is explicit and prints old -> new.
: > "$CURL_LOG"
make --no-print-directory modules-version > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'modules-version'; }
grep -F '0.2.0' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'modules-version did not print the recorded VERSION'; }
grep -Eq '[0-9a-f]{12}' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'modules-version did not print a 12-char manifest hash'; }
test ! -s "$CURL_LOG" || fail 'modules-version made network calls'
printf '0.3.0\n' > "$REMOTE/VERSION"
: > "$CURL_LOG"
make --no-print-directory modules-update > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'modules-update'; }
grep -F '0.2.0 -> 0.3.0' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'modules-update did not print old -> new'; }
test "$(cat .makefiles/modules/VERSION)" = "0.3.0" || fail 'modules-update did not refresh the cached VERSION'
make --no-print-directory modules-version > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'modules-version after update'; }
grep -F '0.3.0' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail 'modules-version did not reflect the update'; }

# 7. A normal build never re-fetches because the site is newer (updates stay explicit).
printf '0.4.0\n' > "$REMOTE/VERSION"
: > "$CURL_LOG"
make --no-print-directory wtree help > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'scoped build with newer site VERSION'; }
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
WTREE_BIN="$PWD/.makefiles/tools/wtree-fake" make --no-print-directory -f .makefiles/modules/wtree/Makefile mf-wtree-ensure > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'direct -f ensure with corrupted cache'; }
cmp "$repo/modules/wtree/targets.mk" .makefiles/modules/wtree/targets.mk || fail 'direct -f ensure did not restore the corrupted file'

echo 'verify-cache tests passed'
