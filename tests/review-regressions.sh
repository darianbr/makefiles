#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; echo "FAIL: review-regressions.sh:$LINENO: $BASH_COMMAND (exit $rc)" >&2' ERR

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp_base=${TMPDIR:-/tmp}
tmp_base=${tmp_base%/}
tmp=$(mktemp -d "$tmp_base/makefiles-review.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/remote" "$tmp/project"
cp -R "$repo/modules/." "$tmp/remote/"
cat > "$tmp/bin/php" <<'SH'
#!/bin/sh
if [ "${1:-}" = "-m" ]; then echo xdebug; fi
exit 0
SH
cat > "$tmp/bin/phpunit" <<'SH'
#!/bin/sh
exit 0
SH
cat > "$tmp/bin/codecept" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$tmp/bin/php" "$tmp/bin/phpunit" "$tmp/bin/codecept"
export PHP="$tmp/bin/php" PHPUNIT="$tmp/bin/phpunit" CODECEPTION="$tmp/bin/codecept"

# Simulate the published site without network access.
cat > "$tmp/bin/curl" <<'SH'
#!/bin/sh
set -eu
url=; out=
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    --max-time|--connect-timeout) shift 2 ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done
path=${url#https://test.invalid/modules/}
printf '%s\n' "$path" >> "$CURL_LOG"
[ "$path" != "${FAIL_PATH:-}" ] || exit 22
cp "$REMOTE/$path" "$out"
SH
chmod +x "$tmp/bin/curl"
export REMOTE="$tmp/remote" CURL_LOG="$tmp/curl.log"
export PATH="$tmp/bin:$PATH" MAKEFILES_BASE_URL=https://test.invalid/modules
fetch_bash=${FETCH_BASH:-bash}
: > "$CURL_LOG"

cd "$tmp/project"
if ! "$fetch_bash" "$repo/fetch" phpunit >"$tmp/out" 2>&1; then
  echo 'Expected initial module fetch to succeed:' >&2
  cat "$tmp/out" >&2
  exit 1
fi
while IFS= read -r path || [ -n "$path" ]; do
  case "$path" in
    Makefile|core/*|phpunit/*)
      if ! cmp "$REMOTE/$path" ".makefiles/modules/$path"; then
        echo "Expected fetched file: $path" >&2
        cat "$tmp/out" >&2
        exit 1
      fi
      ;;
  esac
done < "$REMOTE/manifest.txt"
test -x .makefiles/modules/phpunit/discover-paths.sh
test -x .makefiles/modules/core/open-browser.sh
# The cache records a verifiable hash of every file and carries the module-set VERSION.
test -f .makefiles/modules/.manifest.sha256
( cd .makefiles/modules && if command -v sha256sum >/dev/null 2>&1; then sha256sum -c --quiet .manifest.sha256; else shasum -a 256 -c .manifest.sha256; fi )
test -s .makefiles/modules/VERSION
cp .makefiles/modules/phpunit/Makefile "$tmp/original"
cp .makefiles/modules/Makefile "$tmp/original-root"
cp .makefiles/modules/manifest.txt "$tmp/original-manifest"

# Existing modules skip the network; failed force refresh preserves the cache.
: > "$CURL_LOG"
"$fetch_bash" "$repo/fetch" phpunit >/dev/null
test ! -s "$CURL_LOG"
printf '%s\n' changed > "$REMOTE/Makefile"
if FAIL_PATH=phpunit/targets.mk "$fetch_bash" "$repo/fetch" phpunit --force >"$tmp/out" 2>&1; then
  echo 'Expected a failed fetch' >&2; exit 1
fi
cmp "$tmp/original" .makefiles/modules/phpunit/Makefile
cmp "$tmp/original-root" .makefiles/modules/Makefile
cmp "$tmp/original-manifest" .makefiles/modules/manifest.txt
if FAIL_PATH=typescript/targets.mk "$fetch_bash" "$repo/fetch" typescript >"$tmp/out" 2>&1; then
  echo 'Expected a failed first fetch' >&2; exit 1
fi
test ! -e .makefiles/modules/typescript/Makefile
"$fetch_bash" "$repo/fetch" typescript >/dev/null
test -f .makefiles/modules/typescript/targets.mk
# Restore the root snapshot after the successful TypeScript fetch.
cp "$tmp/original-root" .makefiles/modules/Makefile
if "$fetch_bash" "$repo/fetch" unknown >"$tmp/out" 2>&1 || ! grep -q "module 'unknown' not found" "$tmp/out"; then
  echo 'Expected unknown module rejection' >&2; exit 1
fi
test ! -e .makefiles/modules/unknown/Makefile
if "$fetch_bash" "$repo/fetch" ../phpunit >"$tmp/out" 2>&1 || ! grep -q 'invalid module name' "$tmp/out"; then
  echo 'Expected unsafe module name rejection' >&2; exit 1
fi
printf '%s\n' 'phpunit/../escape' >> "$REMOTE/manifest.txt"
if "$fetch_bash" "$repo/fetch" phpunit --force >"$tmp/out" 2>&1 || ! grep -q 'invalid manifest path' "$tmp/out"; then
  echo 'Expected unsafe manifest path rejection' >&2; exit 1
fi
cmp "$tmp/original-root" .makefiles/modules/Makefile
for path in Makefile core/clean.mk phpunit/Makefile; do
  cp "$repo/modules/manifest.txt" "$REMOTE/manifest.txt"
  printf '%s\n' "$path" >> "$REMOTE/manifest.txt"
  if "$fetch_bash" "$repo/fetch" phpunit --force >"$tmp/out" 2>&1 || ! grep -Fq "duplicate manifest path: $path" "$tmp/out"; then
    echo "Expected duplicate manifest path rejection: $path" >&2; exit 1
  fi
  cmp "$tmp/original-root" .makefiles/modules/Makefile
done

# Helpers downloaded by older versions lacked executable permissions.
generation=$(cd .makefiles/modules && pwd -P)
cp -R "$repo/modules/." "$generation/"
chmod -x "$generation/phpunit/discover-paths.sh"
chmod -x "$generation/codeception/discover-paths.sh"
printf '%s\n' '<phpunit><coverage><report><html outputDirectory="custom report"/></report></coverage></phpunit>' > phpunit.xml
printf '%s\n' 'paths:' '  output: custom-output' > codeception.yml
printf '%s\n' '-include .makefiles/modules/phpunit/Makefile' '-include .makefiles/modules/codeception/Makefile' > Makefile
project_physical=$(cd "$tmp/project" && pwd -P)
make --no-print-directory "$project_physical/.makefiles/cache/phpunit-coverage-dir" "$project_physical/.makefiles/cache/codeception-coverage-dir" MF_LEGACY_GOALS=1
test "$(cat .makefiles/cache/phpunit-coverage-dir)" = "$project_physical/custom report"
test "$(cat .makefiles/cache/codeception-coverage-dir)" = "$project_physical/custom-output/coverage"

# The opener selects the requested binary, then xdg-open, then open; it
# retains the project working directory and preserves paths with spaces.
mkdir -p "$tmp/openers"
cat > "$tmp/openers/browser" <<'SH'
#!/bin/sh
printf '%s|%s|%s\n' "${0##*/}" "$PWD" "$1" >> "$BROWSER_LOG"
SH
chmod +x "$tmp/openers/browser"
cp "$tmp/openers/browser" "$tmp/openers/xdg-open"
cp "$tmp/openers/browser" "$tmp/openers/open"
export BROWSER_LOG="$tmp/browser.log"
: > "$BROWSER_LOG"
helper="$repo/modules/core/open-browser.sh"
PATH="$tmp/openers" /bin/sh "$helper" "$tmp/project" phpunit 'report path/index.html' browser
PATH="$tmp/openers" /bin/sh "$helper" "$tmp/project" vitest 'report path/index.html' ''
rm "$tmp/openers/xdg-open"
PATH="$tmp/openers" /bin/sh "$helper" "$tmp/project" codeception 'report path/index.html' ''
cat > "$tmp/expected" <<EXPECTED
browser|$tmp/project|report path/index.html
xdg-open|$tmp/project|report path/index.html
open|$tmp/project|report path/index.html
EXPECTED
diff -u "$tmp/expected" "$BROWSER_LOG"
if PATH="$tmp/openers" /bin/sh "$helper" "$tmp/project" vitest report missing >"$tmp/out" 2>&1 || ! grep -q 'Browser opener not found: missing' "$tmp/out"; then
  echo 'Expected missing explicit browser error' >&2; exit 1
fi
rm "$tmp/openers/open"
if PATH="$tmp/openers" /bin/sh "$helper" "$tmp/project" phpunit report '' >"$tmp/out" 2>&1 || ! grep -q 'No browser opener found' "$tmp/out"; then
  echo 'Expected missing default browser error' >&2; exit 1
fi
printf '%s\n' '#!/bin/sh' 'exit 9' > "$tmp/openers/fails"
chmod +x "$tmp/openers/fails"
if PATH="$tmp/openers" /bin/sh "$helper" "$tmp/project" vitest report fails >"$tmp/out" 2>&1; then
  echo 'Expected opener failure to propagate' >&2; exit 1
fi

# Each public module target delegates the correct cached report to the helper.
generation=$(cd .makefiles/modules && pwd -P)
cp -R "$repo/modules/." "$generation/"
cat > Makefile <<'MAKE'
-include .makefiles/modules/phpunit/Makefile
-include .makefiles/modules/codeception/Makefile
-include .makefiles/modules/vitest/Makefile
MAKE
for module in phpunit codeception vitest; do
  cache="$project_physical/.makefiles/cache/$module-coverage-index"
  printf '%s\n' "$project_physical/$module report/index.html" > "$cache"
  make --no-print-directory -f ".makefiles/modules/$module/Makefile" -o "$cache" MF_SCOPED_MODULE="$module" coverage-open "BROWSER=$tmp/openers/browser"
done
tail -n 3 "$BROWSER_LOG" > "$tmp/actual"
cat > "$tmp/expected" <<EXPECTED
browser|$project_physical|$project_physical/phpunit report/index.html
browser|$project_physical|$project_physical/codeception report/index.html
browser|$project_physical|$project_physical/vitest report/index.html
EXPECTED
diff -u "$tmp/expected" "$tmp/actual"
echo 'Review regression checks passed.'