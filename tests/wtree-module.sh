#!/usr/bin/env bash
set -euo pipefail
unset MAKEFLAGS GNUMAKEFLAGS MF_LEGACY_GOALS MF_SCOPED_MODULE
unset WTREE_VERSION WTREE_BIN WTREE_RELEASE_URL WTREE_PORT WTREE_SLUG WTREE_CONTAINER_ENGINE WTREE_CERT_FILE WTREE_KEY_FILE

repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
real_tar=$(command -v tar)
real_make=$(command -v "${MAKE_BIN:-make}")
real_sha256sum=$(command -v sha256sum || true)
real_shasum=$(command -v shasum || true)
if [[ -z "$real_sha256sum" && -z "$real_shasum" ]]; then
  echo 'tests require sha256sum or shasum' >&2
  exit 1
fi
export real_tar real_sha256sum real_shasum
export FIXTURE="$tmp" CURL_LOG="$tmp/curl.log" CLI_LOG="$tmp/cli.log" TOOL_LOG="$tmp/tool.log"
mkdir -p "$tmp/bin" "$tmp/releases" "$tmp/archive" "$tmp/project"
(cd "$tmp/project" && MAKEFILES_BASE_URL="file://$repo/modules" bash "$repo/fetch" wtree)
cat > "$tmp/project/Makefile" <<'EOF'
-include .makefiles/modules/wtree/Makefile
EOF
for version in 0.1.0 0.2.0; do
  printf '#!/bin/sh\nfixture_version=%s\n' "$version" > "$tmp/archive/wtree"
  cat >> "$tmp/archive/wtree" <<'EOF'
printf 'args:' >> "$CLI_LOG"
printf ' <%s>' "$@" >> "$CLI_LOG"
printf '\nversion=<%s> engine=<%s> cert=<%s> key=<%s>\n' "$fixture_version" "${WTREE_CONTAINER_ENGINE-}" "${WTREE_CERT_FILE-}" "${WTREE_KEY_FILE-}" >> "$CLI_LOG"
EOF
  chmod +x "$tmp/archive/wtree"
  "$real_tar" -czf "$tmp/releases/wtree_${version}_linux_amd64.tar.gz" -C "$tmp/archive" wtree
done
"$real_tar" -czf "$tmp/releases/wtree_0.2.0_darwin_arm64.tar.gz" -C "$tmp/archive" wtree
if [[ -n "$real_sha256sum" ]]; then
  (cd "$tmp/releases" && "$real_sha256sum" *.tar.gz > SHA256SUMS)
else
  (cd "$tmp/releases" && "$real_shasum" -a 256 *.tar.gz > SHA256SUMS)
fi
cat > "$tmp/bin/curl" <<'EOF'
#!/bin/sh
set -eu
url= out= protocol= redirect_protocol=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    --proto) protocol=$2; shift 2 ;;
    --proto-redir) redirect_protocol=$2; shift 2 ;;
    --max-time|--connect-timeout) shift 2 ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done
printf '%s\n' "$url" >> "$CURL_LOG"
case "$url" in https://*) ;; *) exit 1 ;; esac
[ "$protocol" = '=https' ] && [ "$redirect_protocol" = '=https' ] || { echo 'curl must forbid non-HTTPS redirects' >&2; exit 1; }
cp "$FIXTURE/releases/${url##*/}" "$out"
EOF
cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
case "$1" in -s) echo "${TEST_OS:-Linux}" ;; -m) echo "${TEST_ARCH:-x86_64}" ;; *) exit 1 ;; esac
EOF
cat > "$tmp/bin/tar" <<'EOF'
#!/bin/sh
echo tar >> "$TOOL_LOG"
exec "$real_tar" "$@"
EOF
cat > "$tmp/bin/sha256sum" <<'EOF'
#!/bin/sh
echo sha256sum >> "$TOOL_LOG"
if [ -n "$real_sha256sum" ]; then exec "$real_sha256sum" "$@"; fi
exec "$real_shasum" -a 256 "$@"
EOF
cat > "$tmp/bin/shasum" <<'EOF'
#!/bin/sh
echo shasum >> "$TOOL_LOG"
if [ -n "$real_shasum" ]; then exec "$real_shasum" "$@"; fi
shift 2
exec "$real_sha256sum" "$@"
EOF
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
cd "$tmp/project"
fail() { echo "FAIL: $*" >&2; exit 1; }
run() { "$real_make" --no-print-directory "$@" >"$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail "make $*"; }; }
fails() { if "$real_make" --no-print-directory "$@" >"$tmp/out" 2>&1; then fail "expected make $* to fail"; fi; }
contains() { grep -F -- "$2" "$1" >/dev/null || { cat "$1" >&2; fail "missing $2"; }; }

# Help and scoped clean must not provision binaries or invoke the CLI.
run wtree help
contains "$tmp/out" 'Available targets: clean down help install status up'
run wtree clean
[[ ! -e "$CURL_LOG" && ! -e "$CLI_LOG" && ! -d .makefiles/tools ]] || fail 'help/clean had side effects'

# A missing or empty port must fail before installation or CLI execution.
fails wtree up
contains "$tmp/out" 'WTREE_PORT'
[[ ! -e "$CURL_LOG" && ! -e "$CLI_LOG" && ! -d .makefiles/tools ]] || fail 'missing port had side effects'
for invocation in 'wtree up' 'up'; do
  # Intentional splitting selects the scoped and aggregate forms.
  fails $invocation WTREE_PORT=
  contains "$tmp/out" 'WTREE_PORT'
  [[ ! -e "$CURL_LOG" && ! -e "$CLI_LOG" && ! -d .makefiles/tools ]] || fail 'empty port had side effects'
done
fails -j4 wtree up WTREE_PORT=
contains "$tmp/out" 'WTREE_PORT'
[[ ! -e "$CURL_LOG" && ! -e "$CLI_LOG" && ! -d .makefiles/tools ]] || fail 'parallel empty port had side effects'

# First run downloads exactly the target archive and manifest, verifies and executes it.
run wtree up WTREE_PORT=3000 WTREE_SLUG=my-branch WTREE_CONTAINER_ENGINE=podman WTREE_CERT_FILE='/cert path/fullchain.pem' WTREE_KEY_FILE='/key path/privkey.pem'
[[ -x .makefiles/tools/wtree-0.1.0 ]] || fail 'binary missing or not executable'
[[ $(wc -l < "$CURL_LOG") -eq 2 ]] || fail 'expected exactly two downloads'
contains "$CURL_LOG" '/v0.1.0/wtree_0.1.0_linux_amd64.tar.gz'
contains "$CURL_LOG" '/v0.1.0/SHA256SUMS'
contains "$TOOL_LOG" sha256sum
contains "$TOOL_LOG" tar
contains "$CLI_LOG" 'args: <up> <--port> <3000> <--slug> <my-branch>'
contains "$CLI_LOG" 'version=<0.1.0> engine=<podman> cert=</cert path/fullchain.pem> key=</key path/privkey.pem>'
run wtree status
run wtree down WTREE_SLUG=my-branch
contains "$CLI_LOG" 'args: <status>'
contains "$CLI_LOG" 'args: <down> <--slug> <my-branch>'
[[ $(wc -l < "$CURL_LOG") -eq 2 ]] || fail 'cached binary was downloaded again'
before=$(wc -l < "$CLI_LOG")
fails wtree up WTREE_PORT=
contains "$tmp/out" 'WTREE_PORT'
[[ $(wc -l < "$CLI_LOG") -eq $before && $(wc -l < "$CURL_LOG") -eq 2 ]] || fail 'empty port invoked cached CLI or downloaded'

# Make variable values are data, not shell fragments, even when they contain quotes.
hostile_slug="x'; touch shell-injected; #"
run wtree down "WTREE_SLUG=$hostile_slug"
contains "$CLI_LOG" "args: <down> <--slug> <$hostile_slug>"
[[ ! -e shell-injected ]] || fail 'slug executed shell commands'
hostile_port="3'; touch shell-injected; #"
run wtree up "WTREE_PORT=$hostile_port"
contains "$CLI_LOG" "args: <up> <--port> <$hostile_port>"
[[ ! -e shell-injected ]] || fail 'port executed shell commands'

run wtree install WTREE_VERSION=0.2.0
[[ -x .makefiles/tools/wtree-0.2.0 ]] || fail 'version did not select a new cache path'
contains "$CURL_LOG" '/v0.2.0/wtree_0.2.0_linux_amd64.tar.gz'
run wtree status WTREE_VERSION=0.2.0
contains "$CLI_LOG" 'version=<0.2.0>'
run wtree down
contains "$CLI_LOG" 'args: <down>'
TEST_OS=Darwin TEST_ARCH=arm64 run wtree install WTREE_VERSION=0.2.0 'WTREE_BIN=custom tools/wtree'
[[ -x 'custom tools/wtree' ]] || fail 'custom binary path with spaces was not installed'
contains "$CURL_LOG" '/v0.2.0/wtree_0.2.0_darwin_arm64.tar.gz'
run wtree status 'WTREE_BIN=custom tools/wtree'

# Paths and URLs with shell metacharacters must remain literal installer inputs.
literal_bin="custom 'tools/wtree:release"
run wtree install WTREE_VERSION=0.2.0 "WTREE_BIN=$literal_bin" "WTREE_RELEASE_URL=https://example.test/it's-a-release"
[[ -x "$literal_bin" ]] || fail 'quoted custom path was not installed'
contains "$CURL_LOG" "https://example.test/it's-a-release/wtree_0.2.0_linux_amd64.tar.gz"
run wtree status "WTREE_BIN=$literal_bin"
backslash_bin='custom \tools/wtree'
run wtree install WTREE_VERSION=0.2.0 "WTREE_BIN=$backslash_bin"
[[ -x "$backslash_bin" ]] || fail 'backslash custom path was not installed'
run wtree install WTREE_VERSION=0.2.0 WTREE_BIN=local-wtree
run wtree status WTREE_BIN=local-wtree
run wtree install WTREE_VERSION=0.2.0 WTREE_BIN=-wtree
run wtree status WTREE_BIN=-wtree

# An existing non-executable file is not a usable installed binary.
mkdir -p unusable
printf 'incomplete download\n' > unusable/wtree
run wtree install WTREE_VERSION=0.2.0 WTREE_BIN=unusable/wtree
[[ -x unusable/wtree ]] || fail 'non-executable cached binary was accepted'
run wtree status WTREE_BIN=unusable/wtree
contains "$CLI_LOG" 'args: <status>'
ln -s unusable/wtree linked-wtree
downloads=$(wc -l < "$CURL_LOG")
fails wtree install WTREE_BIN=linked-wtree
contains "$tmp/out" 'WTREE_BIN'
fails wtree install WTREE_BIN=unusable
contains "$tmp/out" 'WTREE_BIN'
[[ -L linked-wtree && -d unusable && $(wc -l < "$CURL_LOG") -eq $downloads ]] || fail 'invalid cache destination had side effects'

before=$(wc -l < "$CLI_LOG")
run wtree clean
[[ $(wc -l < "$CLI_LOG") -eq $before && -x .makefiles/tools/wtree-0.1.0 ]] || fail 'clean touched CLI or binary'

# A consumer can compose the module with a project-owned foreground server.
cat > Makefile <<'EOF'
WTREE_PORT ?= 8000
export WTREE_PORT
include .makefiles/modules/wtree/Makefile
.PHONY: start stop
start:
EOF
printf '\t%s\n' '$(MAKE) wtree up' 'python3 -m http.server "$$WTREE_PORT" --bind 127.0.0.1' >> Makefile
printf 'stop:\n\t%s\n' '$(MAKE) wtree down' >> Makefile
cat > "$tmp/bin/python3" <<'EOF'
#!/bin/sh
printf 'server:' >> "$CLI_LOG"
printf ' <%s>' "$@" >> "$CLI_LOG"
printf '\n' >> "$CLI_LOG"
EOF
chmod +x "$tmp/bin/python3"
run start WTREE_PORT=3456 WTREE_SLUG=example
run stop WTREE_SLUG=example
contains "$CLI_LOG" 'args: <up> <--port> <3456> <--slug> <example>'
contains "$CLI_LOG" 'server: <-m> <http.server> <3456> <--bind> <127.0.0.1>'
contains "$CLI_LOG" 'args: <down> <--slug> <example>'
hostile_consumer_port='3"; touch consumer-injected; #'
run start "WTREE_PORT=$hostile_consumer_port"
contains "$CLI_LOG" "args: <up> <--port> <$hostile_consumer_port>"
contains "$CLI_LOG" "server: <-m> <http.server> <$hostile_consumer_port> <--bind> <127.0.0.1>"
[[ ! -e consumer-injected ]] || fail 'consumer port executed shell commands'

# Checksum mismatch, absent entry, unsupported platform, and missing tools fail closed.
rm -f .makefiles/tools/wtree-0.2.0
printf '%064d  wtree_0.2.0_linux_amd64.tar.gz\n' 0 > "$tmp/releases/SHA256SUMS"
fails wtree install WTREE_VERSION=0.2.0
contains "$tmp/out" 'checksum'
[[ ! -e .makefiles/tools/wtree-0.2.0 ]] || fail 'corrupt binary installed'
printf '%064d  other.tar.gz\n' 0 > "$tmp/releases/SHA256SUMS"
fails wtree install WTREE_VERSION=0.2.0
contains "$tmp/out" 'checksum'
[[ ! -e .makefiles/tools/wtree-0.2.0 ]] || fail 'binary installed without manifest entry'
printf '%064d  wtree_0.2.0_linux_amd64.tar.gz\n%064d  wtree_0.2.0_linux_amd64.tar.gz\n' 0 0 > "$tmp/releases/SHA256SUMS"
fails wtree install WTREE_VERSION=0.2.0
contains "$tmp/out" 'duplicate checksum'
[[ ! -e .makefiles/tools/wtree-0.2.0 ]] || fail 'binary installed with duplicate checksums'
fails wtree install "WTREE_VERSION=x'; touch shell-injected; #" WTREE_BIN=invalid-version
contains "$tmp/out" 'invalid WTREE_VERSION'
[[ ! -e shell-injected && ! -e invalid-version ]] || fail 'invalid version had side effects'
for invalid_version in v0.2.0 0.2_0; do
  fails wtree install "WTREE_VERSION=$invalid_version" WTREE_BIN=invalid-version
  contains "$tmp/out" 'invalid WTREE_VERSION'
  [[ ! -e invalid-version ]] || fail 'invalid release version was installed'
done
TEST_OS=FreeBSD fails wtree install WTREE_VERSION=0.2.0
contains "$tmp/out" 'unsupported'
TEST_ARCH=riscv64 fails wtree install WTREE_VERSION=0.2.0
contains "$tmp/out" 'unsupported'
fails wtree install WTREE_VERSION=0.2.0 WTREE_RELEASE_URL=http://example.invalid
contains "$tmp/out" 'HTTPS'
fails wtree install WTREE_VERSION=0.3.0
[[ ! -e .makefiles/tools/wtree-0.3.0 ]] || fail 'failed download installed binary'
mkdir "$tmp/empty-path"
if PATH="$tmp/empty-path" "$real_make" --no-print-directory wtree install WTREE_VERSION=0.2.0 >"$tmp/out" 2>&1; then
  fail 'missing curl was accepted'
fi
contains "$tmp/out" 'required tool not found: curl'
[[ ! -e .makefiles/tools/wtree-0.2.0 ]] || fail 'failed bootstrap installed binary'
[[ -z $(find .makefiles/tools -name '.wtree.*' -print) ]] || fail 'temporary files remain after failure'

# Exercise the macOS-style shasum fallback with sha256sum absent from PATH.
if [[ -n "$real_sha256sum" ]]; then
  (cd "$tmp/releases" && "$real_sha256sum" *.tar.gz > SHA256SUMS)
else
  (cd "$tmp/releases" && "$real_shasum" -a 256 *.tar.gz > SHA256SUMS)
fi
mkdir "$tmp/fallback-path"
for tool in curl uname tar shasum gzip cp awk mktemp mkdir chmod mv rm echo; do
  ln -s "$(type -P "$tool")" "$tmp/fallback-path/$tool"
done
PATH="$tmp/fallback-path" "$real_make" --no-print-directory wtree install WTREE_VERSION=0.2.0 >"$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'shasum fallback'; }
contains "$TOOL_LOG" shasum
[[ -x .makefiles/tools/wtree-0.2.0 ]] || fail 'shasum fallback did not install binary'

# A correctly checksummed archive with a symlink is not an executable artifact.
rm -f .makefiles/tools/wtree-0.2.0 "$tmp/archive/wtree"
ln -s SHA256SUMS "$tmp/archive/wtree"
"$real_tar" -czf "$tmp/releases/wtree_0.2.0_linux_amd64.tar.gz" -C "$tmp/archive" wtree
if [[ -n "$real_sha256sum" ]]; then
  (cd "$tmp/releases" && "$real_sha256sum" *.tar.gz > SHA256SUMS)
else
  (cd "$tmp/releases" && "$real_shasum" -a 256 *.tar.gz > SHA256SUMS)
fi
fails wtree install WTREE_VERSION=0.2.0
contains "$tmp/out" 'regular wtree binary'
[[ ! -e .makefiles/tools/wtree-0.2.0 ]] || fail 'symlink archive installed'

# Hardlinks are not regular executable payloads either, even when their target
# happens to exist in the installation directory.
rm "$tmp/archive/wtree"
printf 'not a binary\n' > "$tmp/archive/SHA256SUMS"
ln "$tmp/archive/SHA256SUMS" "$tmp/archive/wtree"
"$real_tar" -czf "$tmp/releases/wtree_0.2.0_linux_amd64.tar.gz" -C "$tmp/archive" SHA256SUMS wtree
if [[ -n "$real_sha256sum" ]]; then
  (cd "$tmp/releases" && "$real_sha256sum" *.tar.gz > SHA256SUMS)
else
  (cd "$tmp/releases" && "$real_shasum" -a 256 *.tar.gz > SHA256SUMS)
fi
fails wtree install WTREE_VERSION=0.2.0
contains "$tmp/out" 'regular wtree binary'
[[ ! -e .makefiles/tools/wtree-0.2.0 ]] || fail 'hardlink archive installed'

echo 'wtree module tests passed'