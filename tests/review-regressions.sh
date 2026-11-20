#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/makefiles-review.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/remote" "$tmp/project"
cp -R "$repo/modules/." "$tmp/remote/"

# Simulate the published site without network access.
cat > "$tmp/bin/curl" <<'SH'
#!/bin/sh
set -eu
url=$2
out=$4
path=${url#https://test.invalid/modules/}
printf '%s\n' "$path" >> "$CURL_LOG"
[ "$path" != "${FAIL_PATH:-}" ] || exit 22
cp "$REMOTE/$path" "$out"
SH
chmod +x "$tmp/bin/curl"
export REMOTE="$tmp/remote" CURL_LOG="$tmp/curl.log"
export PATH="$tmp/bin:$PATH" MAKEFILES_BASE_URL=https://test.invalid/modules
: > "$CURL_LOG"

cd "$tmp/project"
bash "$repo/fetch" phpunit >/dev/null
test -x .makefiles/modules/phpunit/discover-paths.sh
test -x .makefiles/modules/core/open-browser.sh
cp .makefiles/modules/phpunit/Makefile "$tmp/original"
cp .makefiles/modules/Makefile "$tmp/original-root"
cp .makefiles/modules/manifest.txt "$tmp/original-manifest"

# Existing modules skip the network; failed force refresh preserves the cache.
: > "$CURL_LOG"
bash "$repo/fetch" phpunit >/dev/null
test ! -s "$CURL_LOG"
printf '%s\n' changed > "$REMOTE/Makefile"
if FAIL_PATH=phpunit/targets.mk bash "$repo/fetch" phpunit --force >"$tmp/out" 2>&1; then
  echo 'Expected a failed fetch' >&2; exit 1
fi
cmp "$tmp/original" .makefiles/modules/phpunit/Makefile
cmp "$tmp/original-root" .makefiles/modules/Makefile
cmp "$tmp/original-manifest" .makefiles/modules/manifest.txt
if FAIL_PATH=typescript/targets.mk bash "$repo/fetch" typescript >"$tmp/out" 2>&1; then
  echo 'Expected a failed first fetch' >&2; exit 1
fi
test ! -e .makefiles/modules/typescript/Makefile
bash "$repo/fetch" typescript >/dev/null
test -f .makefiles/modules/typescript/targets.mk
# Restore the root snapshot after the successful TypeScript fetch.
cp "$tmp/original-root" .makefiles/modules/Makefile
if bash "$repo/fetch" unknown >"$tmp/out" 2>&1 || ! grep -q "module 'unknown' not found" "$tmp/out"; then
  echo 'Expected unknown module rejection' >&2; exit 1
fi
test ! -e .makefiles/modules/unknown/Makefile
if bash "$repo/fetch" ../phpunit >"$tmp/out" 2>&1 || ! grep -q 'invalid module name' "$tmp/out"; then
  echo 'Expected unsafe module name rejection' >&2; exit 1
fi
printf '%s\n' 'phpunit/../escape' >> "$REMOTE/manifest.txt"
if bash "$repo/fetch" phpunit --force >"$tmp/out" 2>&1 || ! grep -q 'invalid manifest path' "$tmp/out"; then
  echo 'Expected unsafe manifest path rejection' >&2; exit 1
fi
cmp "$tmp/original-root" .makefiles/modules/Makefile
cp "$repo/modules/manifest.txt" "$REMOTE/manifest.txt"
printf '%s\n' 'phpunit/Makefile' >> "$REMOTE/manifest.txt"
if bash "$repo/fetch" phpunit --force >"$tmp/out" 2>&1 || ! grep -q 'duplicate manifest path' "$tmp/out"; then
  echo 'Expected duplicate manifest path rejection' >&2; exit 1
fi
cmp "$tmp/original-root" .makefiles/modules/Makefile

# Helpers downloaded by older versions lacked executable permissions.
cp -R "$repo/modules/codeception" .makefiles/modules/
chmod -x .makefiles/modules/phpunit/discover-paths.sh
chmod -x .makefiles/modules/codeception/discover-paths.sh
printf '%s\n' '<phpunit><coverage><report><html outputDirectory="custom report"/></report></coverage></phpunit>' > phpunit.xml
printf '%s\n' 'paths:' '  output: custom-output' > codeception.yml
printf '%s\n' '-include .makefiles/modules/phpunit/Makefile' '-include .makefiles/modules/codeception/Makefile' > Makefile
make --no-print-directory "$tmp/project/.makefiles/cache/phpunit-coverage-dir" "$tmp/project/.makefiles/cache/codeception-coverage-dir" MF_LEGACY_GOALS=1
test "$(cat .makefiles/cache/phpunit-coverage-dir)" = "$tmp/project/custom report"
test "$(cat .makefiles/cache/codeception-coverage-dir)" = "$tmp/project/custom-output/coverage"

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
cp -R "$repo/modules/." .makefiles/modules/
cat > Makefile <<'MAKE'
-include .makefiles/modules/phpunit/Makefile
-include .makefiles/modules/codeception/Makefile
-include .makefiles/modules/vitest/Makefile
MAKE
for module in phpunit codeception vitest; do
  cache="$tmp/project/.makefiles/cache/$module-coverage-index"
  printf '%s\n' "$tmp/project/$module report/index.html" > "$cache"
  make --no-print-directory -f ".makefiles/modules/$module/Makefile" -o "$cache" MF_SCOPED_MODULE="$module" coverage-open "BROWSER=$tmp/openers/browser"
done
tail -n 3 "$BROWSER_LOG" > "$tmp/actual"
cat > "$tmp/expected" <<EXPECTED
browser|$tmp/project|$tmp/project/phpunit report/index.html
browser|$tmp/project|$tmp/project/codeception report/index.html
browser|$tmp/project|$tmp/project/vitest report/index.html
EXPECTED
diff -u "$tmp/expected" "$tmp/actual"
echo 'Review regression checks passed.'