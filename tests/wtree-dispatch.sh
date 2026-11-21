#!/usr/bin/env bash
set -euo pipefail
unset MAKEFLAGS GNUMAKEFLAGS MF_LEGACY_GOALS MF_SCOPED_MODULE WTREE_BIN WTREE_VERSION WTREE_PORT WTREE_SLUG

repo=$(cd "$(dirname "$0")/.." && pwd -P)
make_bin=${MAKE_BIN:-make}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/project" "$tmp/bin" "$tmp/bootstrap"
cat > "$tmp/bootstrap/Makefile" <<'EOF'
-include .makefiles/modules/wtree/Makefile
.makefiles/modules/%/Makefile:
EOF
printf '\t%s\n' 'curl -sf "file://$$MAKEFILES_REPO/fetch" | bash /dev/stdin $*' >> "$tmp/bootstrap/Makefile"
(cd "$tmp/bootstrap" && MAKEFILES_REPO="$repo" MAKEFILES_BASE_URL="file://$repo/modules" "$make_bin" --no-print-directory wtree help > "$tmp/bootstrap.out" 2>&1) || { cat "$tmp/bootstrap.out" >&2; exit 1; }
grep -F 'Available targets: clean down help install status up' "$tmp/bootstrap.out" >/dev/null
cmp "$repo/modules/manifest.txt" "$tmp/bootstrap/.makefiles/modules/manifest.txt"
[[ ! -d "$tmp/bootstrap/.makefiles/tools" ]] || { echo 'FAIL: bootstrap help installed a binary' >&2; exit 1; }
cd "$tmp/project"
MAKEFILES_BASE_URL="file://$repo/modules" bash "$repo/fetch" wtree > "$tmp/fetch.out"
cmp "$repo/modules/manifest.txt" .makefiles/modules/manifest.txt
while IFS= read -r file; do
  case "$file" in
    Makefile|core/*|wtree/*) cmp "$repo/modules/$file" ".makefiles/modules/$file" ;;
  esac
done < "$repo/modules/manifest.txt"
[[ ! -e .makefiles/modules/npm ]] || { echo 'FAIL: fetch included an unrelated module' >&2; exit 1; }
printf 'damaged\n' > .makefiles/modules/wtree/targets.mk
MAKEFILES_BASE_URL="file://$repo/modules" bash "$repo/fetch" wtree > "$tmp/fetch.out"
grep -F 'already present' "$tmp/fetch.out" >/dev/null
MAKEFILES_BASE_URL="file://$repo/modules" bash "$repo/fetch" wtree --force > "$tmp/fetch.out"
cmp "$repo/modules/wtree/targets.mk" .makefiles/modules/wtree/targets.mk

mkdir .makefiles/modules/other
cat > .makefiles/modules/other/Makefile <<'EOF'
-include .makefiles/modules/Makefile
MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/other/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),clean install help status))
.PHONY: status other-prerequisite
status:: other-prerequisite
	@echo other-status >> "$$DISPATCH_LOG"
other-prerequisite:
	@echo other-prerequisite >> "$$DISPATCH_LOG"
clean::
	@echo other-clean >> "$$DISPATCH_LOG"
EOF
cat > "$tmp/bin/wtree" <<'EOF'
#!/bin/sh
printf 'wtree-%s\n' "$*" >> "$DISPATCH_LOG"
EOF
cat > "$tmp/bin/true" <<'EOF'
#!/bin/sh
echo 'untrusted true executed' >> "$DISPATCH_LOG"
exit 99
EOF
chmod +x "$tmp/bin/wtree" "$tmp/bin/true"
export PATH="$tmp/bin:$PATH" WTREE_BIN="$tmp/bin/wtree" DISPATCH_LOG="$tmp/dispatch.log"
fail() { echo "FAIL: $*" >&2; exit 1; }
run() { "$make_bin" --no-print-directory "$@" > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail "make $*"; }; }
database() { "$make_bin" --no-print-directory -np "$@" > "$tmp/database" 2>&1 || { tail -40 "$tmp/database" >&2; fail "make database $*"; }; }
assert_log() { printf '%s' "$1" > "$tmp/expected"; diff -u "$tmp/expected" "$DISPATCH_LOG" || fail "$2"; }

[[ -x /usr/bin/true ]] || fail '/usr/bin/true is not executable'
for order in other-first wtree-first; do
  if [[ $order == other-first ]]; then
    printf '%s\n' 'include .makefiles/modules/other/Makefile' 'include .makefiles/modules/wtree/Makefile' > Makefile
  else
    printf '%s\n' 'include .makefiles/modules/wtree/Makefile' 'include .makefiles/modules/other/Makefile' > Makefile
  fi
  for module in wtree other; do
    database "$module" status
    grep -Ex 'status: SHELL := /usr/bin/true|# SHELL := /usr/bin/true' "$tmp/database" >/dev/null || fail "$order: $module status did not select /usr/bin/true"
  done
  for mode in aggregate legacy multiple; do
    case "$mode" in
      aggregate) database status ;;
      legacy) database MF_LEGACY_GOALS=1 status help ;;
      multiple) database status help status ;;
    esac
    if grep -E '^(status: (override )?SHELL[[:space:]]*[:?+]?=|# SHELL := /(usr/)?bin/true)' "$tmp/database" >/dev/null; then
      fail "$order: $mode unexpectedly assigned a target-specific shell"
    fi
  done
  : > "$DISPATCH_LOG"
  run wtree status
  assert_log $'wtree-status\n' "$order: scoped wtree ran an aggregate recipe or ran twice"
  : > "$DISPATCH_LOG"
  run other status
  assert_log $'other-prerequisite\nother-status\n' "$order: scoped other ran an aggregate recipe or ran twice"
  : > "$DISPATCH_LOG"
  run -j4 wtree status
  assert_log $'wtree-status\n' "$order: parallel scoped wtree ran an aggregate recipe or ran twice"
  : > "$DISPATCH_LOG"
  run -j4 other status
  assert_log $'other-prerequisite\nother-status\n' "$order: parallel scoped other ran an aggregate recipe or ran twice"
  : > "$DISPATCH_LOG"
  run status
  if [[ $order == other-first ]]; then
    assert_log $'other-prerequisite\nother-status\nwtree-status\n' "$order: aggregate status changed"
  else
    assert_log $'wtree-status\nother-prerequisite\nother-status\n' "$order: aggregate status changed"
  fi
  : > "$DISPATCH_LOG"
  run MF_LEGACY_GOALS=1 status help
  grep -F 'makefiles help' "$tmp/out" >/dev/null || fail "$order: legacy help did not run"
  [[ $(grep -c '^wtree-status$' "$DISPATCH_LOG") -eq 1 && $(grep -c '^other-status$' "$DISPATCH_LOG") -eq 1 ]] || fail "$order: legacy status did not run both modules once"
  : > "$DISPATCH_LOG"
  run status help status
  [[ $(grep -c '^wtree-status$' "$DISPATCH_LOG") -eq 1 && $(grep -c '^other-status$' "$DISPATCH_LOG") -eq 1 ]] || fail "$order: multiple goals duplicated status"
  echo "dispatch tests passed: $order"
done

# A partial or corrupt core must fail before dispatch or the CLI is invoked.
printf '%s\n' 'include .makefiles/modules/wtree/Makefile' > Makefile
core=.makefiles/modules/core/registry.mk
mv "$core" "$core.saved"
for invalid in missing empty symlink no-registry; do
  case "$invalid" in
    empty) : > "$core" ;;
    symlink) ln -s registry.mk.saved "$core" ;;
    no-registry) printf '# invalid registry\n' > "$core" ;;
  esac
  : > "$DISPATCH_LOG"
  if "$make_bin" --no-print-directory wtree status > "$tmp/out" 2>&1; then
    fail "$invalid core was accepted"
  fi
  grep -E 'wtree: Makefiles (core|module registry) is missing or invalid' "$tmp/out" >/dev/null || { cat "$tmp/out" >&2; fail "$invalid core did not explain the error"; }
  [[ ! -s "$DISPATCH_LOG" ]] || fail "$invalid core ran a recipe"
  rm -f "$core"
done
mv "$core.saved" "$core"
echo 'fetch and core validation tests passed'