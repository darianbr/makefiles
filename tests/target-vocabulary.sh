#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/makefiles-vocab.XXXXXX")
make_bin=$(command -v make)
trap 'rm -rf -- "$tmp_root"' EXIT

mkdir -p "$tmp_root/.makefiles/modules" "$tmp_root/bin"
cp -R "$repo_root/modules/." "$tmp_root/.makefiles/modules/"
# Model a fetched cache, including verification metadata, rather than a raw
# copy of the published files without the record fetch normally writes.
(
  cd "$tmp_root/.makefiles/modules"
  if command -v sha256sum >/dev/null 2>&1; then hash_tool=sha256sum; else hash_tool='shasum -a 256'; fi
  while IFS= read -r path; do $hash_tool "$path"; done < manifest.txt
  $hash_tool manifest.txt
) > "$tmp_root/.makefiles/modules/.manifest.sha256"

# The tests below restrict PATH to omit npm or tsc, but verification still
# needs ordinary system utilities; these links do not provide either tool.
for bin in no-tsc-bin no-npm-bin; do
  mkdir -p "$tmp_root/$bin"
  for utility in mktemp rm awk grep wc sha256sum shasum cp cmp touch head cut cat ls; do
    path=$(command -v "$utility" || true)
    if [ -n "$path" ]; then ln -s "$path" "$tmp_root/$bin/$utility"; fi
  done
done

cat > "$tmp_root/bin/cargo" <<'SH'
#!/bin/sh
printf 'cargo %s\n' "$*" >> "$COMMAND_LOG"
SH
cat > "$tmp_root/bin/tsc" <<'SH'
#!/bin/sh
printf 'tsc %s\n' "$*" >> "$COMMAND_LOG"
SH
cat > "$tmp_root/bin/npm" <<'SH'
#!/bin/sh
printf 'npm %s\n' "$*" >> "$COMMAND_LOG"
SH
chmod +x "$tmp_root/bin/cargo" "$tmp_root/bin/tsc" "$tmp_root/bin/npm"

export PATH="$tmp_root/bin:$PATH"
export COMMAND_LOG="$tmp_root/commands.log"
export CARGO=cargo
export TSC="$tmp_root/bin/tsc"
export NPM=npm
: > "$COMMAND_LOG"

cat > "$tmp_root/Cargo.toml" <<'TOML'
[package]
name = "vocabulary-fixture"
version = "0.1.0"
edition = "2021"
TOML
cat > "$tmp_root/package.json" <<'JSON'
{}
JSON
cat > "$tmp_root/tsconfig.json" <<'JSON'
{}
JSON

cat > "$tmp_root/Makefile" <<'MAKE'
-include .makefiles/modules/rust/Makefile
-include .makefiles/modules/typescript/Makefile
MAKE

make_in_fixture() {
  "$make_bin" --no-print-directory -C "$tmp_root" "$@"
}

# Generated help reflects registered optional targets without executing them.
aggregate_help=$(make_in_fixture help)
[[ "$aggregate_help" == *check* && "$aggregate_help" == *release* ]]
rust_help=$(make_in_fixture rust help)
[[ "$rust_help" == *check* && "$rust_help" == *release* ]]

# Aggregate check is static-only and composes in module import order.
make_in_fixture check
cat > "$tmp_root/expected.log" <<'EXPECTED'
cargo check --locked
tsc --noEmit -p tsconfig.json
EXPECTED
diff -u "$tmp_root/expected.log" "$COMMAND_LOG"

# Aggregate build composes Rust and TypeScript; release runs only where offered.
: > "$COMMAND_LOG"
make_in_fixture build
cat > "$tmp_root/expected.log" <<'EXPECTED'
cargo build
tsc -p tsconfig.json --outDir build/typescript
EXPECTED
diff -u "$tmp_root/expected.log" "$COMMAND_LOG"

: > "$COMMAND_LOG"
make_in_fixture release CARGO_RELEASE_ARGS=--workspace
printf 'cargo build --release --workspace\n' > "$tmp_root/expected.log"
diff -u "$tmp_root/expected.log" "$COMMAND_LOG"

# Rust exposes separate development, release, and test workflows.
: > "$COMMAND_LOG"
make_in_fixture rust build
make_in_fixture rust release CARGO_RELEASE_ARGS=--workspace
make_in_fixture rust test
cat > "$tmp_root/expected.log" <<'EXPECTED'
cargo build
cargo build --release --workspace
cargo test
EXPECTED
diff -u "$tmp_root/expected.log" "$COMMAND_LOG"

# TypeScript typechecking is named check and is listed in scoped help, not test.
typescript_help=$(make_in_fixture typescript help)
[[ "$typescript_help" == *check* ]]
if [[ "$typescript_help" =~ (^|[[:space:]])test([[:space:]]|$) ]]; then
  echo "TypeScript help still advertises test instead of check" >&2
  exit 1
fi

set +e
make_in_fixture typescript test >"$tmp_root/test.stdout" 2>"$tmp_root/test.stderr"
test_status=$?
set -e
if [[ $test_status -ne 2 ]] || ! grep -q "target 'test' is not available in module 'typescript'" "$tmp_root/test.stderr"; then
  echo "Expected scoped TypeScript test to be rejected; status was $test_status" >&2
  cat "$tmp_root/test.stderr" >&2
  exit 1
fi

# The Rust scoped check must not run TypeScript's aggregate contribution.
: > "$COMMAND_LOG"
make_in_fixture rust check
printf 'cargo check --locked\n' > "$tmp_root/expected.log"
diff -u "$tmp_root/expected.log" "$COMMAND_LOG"

# A missing compiler is reported without invoking npm install.
ln -s "$make_bin" "$tmp_root/no-tsc-bin/make"
cp "$tmp_root/bin/npm" "$tmp_root/no-tsc-bin/npm"
: > "$COMMAND_LOG"
set +e
PATH="$tmp_root/no-tsc-bin" make_in_fixture typescript check "TSC=$tmp_root/missing-tsc" >"$tmp_root/missing-tsc.stdout" 2>"$tmp_root/missing-tsc.stderr"
missing_tsc_status=$?
set -e
if [[ $missing_tsc_status -eq 0 ]] || ! grep -q "run 'make typescript install' first" "$tmp_root/missing-tsc.stderr"; then
  echo "Expected missing TypeScript compiler to fail with install guidance" >&2
  cat "$tmp_root/missing-tsc.stderr" >&2
  exit 1
fi
if [[ -s "$COMMAND_LOG" ]]; then
  echo "TypeScript check invoked a command while the compiler was missing" >&2
  cat "$COMMAND_LOG" >&2
  exit 1
fi

# An installed compiler is sufficient; check does not require npm.
: > "$COMMAND_LOG"
PATH="$tmp_root/no-npm-bin" make_in_fixture typescript check 'TSC=./bin/tsc'
printf 'tsc --noEmit -p tsconfig.json\n' > "$tmp_root/expected.log"
diff -u "$tmp_root/expected.log" "$COMMAND_LOG"

# Build likewise uses a configured compiler without depending on npm exec.
: > "$COMMAND_LOG"
PATH="$tmp_root/no-npm-bin" make_in_fixture typescript build 'TSC=./bin/tsc'
printf 'tsc -p tsconfig.json --outDir build/typescript\n' > "$tmp_root/expected.log"
diff -u "$tmp_root/expected.log" "$COMMAND_LOG"

# Current and legacy argument variables are both honored during the rename.
: > "$COMMAND_LOG"
make_in_fixture typescript check 'TSC_CHECK_ARGS=--noEmit -p tsconfig.json --pretty false'
printf 'tsc --noEmit -p tsconfig.json --pretty false\n' > "$tmp_root/expected.log"
diff -u "$tmp_root/expected.log" "$COMMAND_LOG"

: > "$COMMAND_LOG"
make_in_fixture typescript check 'TSC_TEST_ARGS=--noEmit -p tsconfig.json --strict'
printf 'tsc --noEmit -p tsconfig.json --strict\n' > "$tmp_root/expected.log"
diff -u "$tmp_root/expected.log" "$COMMAND_LOG"

echo "Target vocabulary checks passed."
