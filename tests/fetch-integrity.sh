#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/project" "$tmp/bin"
cd "$tmp/project"
export MAKEFILES_BASE_URL="file://$repo/modules"
fetch_bash=${FETCH_BASH:-bash}
"$fetch_bash" "$repo/fetch" wtree > "$tmp/out" 2>&1
record=.makefiles/modules/.manifest.sha256
old=$(awk '$2 == "wtree/targets.mk" {print $1}' "$record")
printf '\nDAMAGED=1\n' >> .makefiles/modules/wtree/targets.mk
"$fetch_bash" "$repo/fetch" phpunit > "$tmp/out" 2>&1
new=$(awk '$2 == "wtree/targets.mk" {print $1}' "$record")
if [[ -z "$old" || "$old" != "$new" ]]; then
  echo 'FAIL: fetching another module blessed a damaged cached file' >&2
  exit 1
fi
# Failure to generate hashes must not alter any cached file or record.
mkdir -p "$tmp/before"
cp -R "$(cd .makefiles/modules && pwd -P)/." "$tmp/before/"
printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/sha256sum"
chmod +x "$tmp/bin/sha256sum"
if PATH="$tmp/bin:$PATH" "$fetch_bash" "$repo/fetch" wtree --force > "$tmp/out" 2>&1; then
  echo 'FAIL: failed checksum command was accepted' >&2
  exit 1
fi
if ! diff -r "$tmp/before" .makefiles/modules; then
  echo 'FAIL: checksum failure changed the existing cache' >&2
  exit 1
fi
# A publication missing VERSION is invalid and must not alter an existing cache.
mkdir -p "$tmp/remote/modules"
cp -R "$repo/modules/." "$tmp/remote/modules/"
awk '$0 != "VERSION"' "$repo/modules/manifest.txt" > "$tmp/remote/modules/manifest.txt"
if MAKEFILES_BASE_URL="file://$tmp/remote/modules" "$fetch_bash" "$repo/fetch" wtree --force > "$tmp/out" 2>&1; then
  echo 'FAIL: manifest without required VERSION was accepted' >&2
  exit 1
fi
grep -q 'VERSION' "$tmp/out" || { echo 'FAIL: missing VERSION was not reported' >&2; exit 1; }
if ! diff -r "$tmp/before" .makefiles/modules; then
  echo 'FAIL: invalid manifest changed the existing cache' >&2
  exit 1
fi
echo 'fetch integrity checks passed'
