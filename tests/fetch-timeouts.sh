#!/usr/bin/env bash
set -euo pipefail

# Verifies every fetch download is bounded by --max-time/--connect-timeout and
# that a curl timeout (exit 28) surfaces as a clear "timed out downloading"
# message instead of a bare curl failure or an unbounded hang.
#
# Uses a fake curl on PATH (same idiom as review-regressions.sh): it asserts the
# timeout flags are present, then simulates curl honoring --max-time by sleeping
# that long and exiting 28 for file downloads. The manifest fetch succeeds so we
# reach the per-file loop.

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/makefiles-timeouts.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/remote" "$tmp/project"
cp -R "$repo/modules/." "$tmp/remote/"

cat > "$tmp/bin/curl" <<'SH'
#!/bin/sh
set -eu
url=; out=; maxtime=; connecttimeout=
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    --max-time) maxtime=$2; shift 2 ;;
    --connect-timeout) connecttimeout=$2; shift 2 ;;
    -*) shift ;;
    *) [ -n "$url" ] || url=$1; shift ;;
  esac
done
[ -n "$maxtime" ] || { echo "fetch did not pass --max-time" >&2; exit 99; }
[ -n "$connecttimeout" ] || { echo "fetch did not pass --connect-timeout" >&2; exit 99; }
path=${url#https://test.invalid/modules/}
if [ "$path" = "manifest.txt" ]; then
  cp "$REMOTE/manifest.txt" "$out"
  exit 0
fi
# Simulate curl honoring --max-time: wait that long, then time out (exit 28).
sleep "$maxtime"
exit 28
SH
chmod +x "$tmp/bin/curl"
export REMOTE="$tmp/remote"
export PATH="$tmp/bin:$PATH" MAKEFILES_BASE_URL=https://test.invalid/modules

cd "$tmp/project"
start=$SECONDS
if MAKEFILES_FETCH_MAX_TIME=1 MAKEFILES_FETCH_CONNECT_TIMEOUT=1 bash "$repo/fetch" wtree >"$tmp/out" 2>"$tmp/err"; then
  echo 'Expected a timed-out fetch to fail' >&2
  exit 1
fi
elapsed=$((SECONDS - start))
if [ "$elapsed" -ge 5 ]; then
  echo "fetch did not finish within 5s (unbounded): ${elapsed}s" >&2
  cat "$tmp/err" >&2
  exit 1
fi
if ! grep -q 'timed out downloading' "$tmp/err"; then
  echo 'Expected a "timed out downloading" message on curl timeout:' >&2
  cat "$tmp/err" >&2
  exit 1
fi
# Neither staging directories nor the writer lock may survive the failed fetch.
if ls .makefiles/.fetch.* >/dev/null 2>&1; then
  echo 'Staging or lock state was not cleaned up after a failed fetch' >&2
  ls -ld .makefiles/.fetch.* >&2
  exit 1
fi
echo "ok: bounded fetch timeout (finished in ${elapsed}s)"
