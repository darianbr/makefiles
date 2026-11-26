#
# Filename: modules/core/verify.mk
# Last edited: 2026-11-22
# Description: Lazy cache verification with one-shot self-heal for corrupted files.
#

# Fetch records sha256sum-verifiable hashes for the files it downloads and
# preserves existing hashes for untouched modules. Verification is local-only: a
# single `sha256sum -c` pass over the recorded lines for the module in use
# plus the shared root/core files it depends on. On mismatch or a missing
# record, the affected module is re-fetched once with --force (via the
# published fetch script, same pattern as the consumer bootstrap rule) and
# verified again; if it still fails, the build stops and names the offending
# file(s). A module absent from the cached manifest is local-only and is
# skipped. Updates are never silent: this only runs on verified corruption or
# a missing record, never because the site is newer.

ifndef MF_VERIFY_INCLUDED
MF_VERIFY_INCLUDED := 1

MF_VERIFY_HASH_FILE := $(MF_MODULES_ROOT).manifest.sha256
# The fetch script is served from the site root; module files live under
# <site>/modules. Recipes derive the fetch URL in-shell (with the same default
# as fetch) so consumers who do not set MAKEFILES_BASE_URL still self-heal.

.PHONY: mf-verify-module mf-verify-all modules-version modules-update

# Verify one module's recorded lines (plus the shared root/core files every
# module depends on). MF_VERIFY_MODULE selects the module; on mismatch or a
# missing record, re-fetch that module once and verify again.
mf-verify-module:
	@module="$(MF_VERIFY_MODULE)"; \
	hashfile="$(MF_VERIFY_HASH_FILE)"; \
	manifest="$(MF_MODULES_ROOT)manifest.txt"; \
	base="$${MAKEFILES_BASE_URL:-https://darianbr.github.io/makefiles/modules}"; \
	fetchurl="$${base%/modules}/fetch"; \
	if [ -z "$$module" ]; then echo 'makefiles: mf-verify-module requires MF_VERIFY_MODULE' >&2; exit 1; fi; \
	tmp=$$(mktemp -d "$${TMPDIR:-/tmp}/makefiles-verify.XXXXXXXX") || exit 1; \
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM; \
	if command -v sha256sum >/dev/null 2>&1; then hashcheck="sha256sum -c --quiet"; \
	elif command -v shasum >/dev/null 2>&1; then hashcheck="shasum -a 256 -c"; \
	else echo 'makefiles: sha256sum or shasum is required to verify the module cache' >&2; exit 1; fi; \
	if [ -f "$$manifest" ] && [ -f "$$hashfile" ] && ! grep -q "^$$module/" "$$manifest"; then \
		awk '$$2 == "manifest.txt" { print }' "$$hashfile" > "$$tmp/manifest-checksum"; \
		if [ "$$(wc -l < "$$tmp/manifest-checksum")" -eq 1 ] && (cd "$(MF_MODULES_ROOT)" && $$hashcheck "$$tmp/manifest-checksum" >/dev/null 2>&1); then exit 0; fi; \
	fi; \
	verify_cache() { \
		if [ ! -f "$$hashfile" ] || [ ! -f "$$manifest" ]; then echo 'missing hash record or manifest' >&2; return 1; fi; \
		awk -v m="$$module" ' \
		  NR == FNR { if (NF == 2 && length($$1) == 64 && $$1 ~ /^[[:xdigit:]]+$$/) { hashes[$$2] = $$0; count[$$2]++ } next } \
		  function require(path) { if (count[path] != 1) { print path ": MISSING OR DUPLICATE" > "/dev/stderr"; bad = 1 } else print hashes[path] } \
		  FNR == 1 { require("manifest.txt") } \
		  $$0 == "Makefile" || $$0 == "VERSION" || index($$0, "core/") == 1 || index($$0, m "/") == 1 { require($$0) } \
		  END { if (bad) exit 1 }' "$$hashfile" "$$manifest" > "$$tmp/checksums" || return 1; \
		(cd "$(MF_MODULES_ROOT)" && $$hashcheck "$$tmp/checksums"); \
	}; \
	verified=0; bad=$$(verify_cache 2>&1) || verified=1; \
	if [ $$verified -ne 0 ]; then \
		offending=$$(printf '%s\n' "$$bad" | grep -E 'FAILED|MISSING|DUPLICATE' | head -n 1 | cut -d: -f1); \
		echo "makefiles: cache verification failed for $$module ($${offending:-$$module}); re-fetching"; \
		rc=0; curl -sf --max-time "$${MAKEFILES_FETCH_MAX_TIME:-30}" --connect-timeout "$${MAKEFILES_FETCH_CONNECT_TIMEOUT:-10}" "$$fetchurl" -o "$$tmp/fetch" || rc=$$?; \
		if [ $$rc -eq 0 ]; then bash "$$tmp/fetch" "$$module" --force || rc=$$?; fi; \
		if [ $$rc -ne 0 ]; then echo "makefiles: cache verification failed for $${offending:-$$module} in module '$$module'; re-fetch also failed (exit $$rc)" >&2; exit 1; fi; \
		bad=$$(verify_cache 2>&1) || { echo "makefiles: cache verification failed for $$bad in module '$$module'; re-fetch also failed" >&2; exit 1; }; \
		if [ -n "$${MF_VERIFY_REPAIRED_MARKER:-}" ]; then : > "$$MF_VERIFY_REPAIRED_MARKER"; fi; \
	fi

# Verify every imported module's recorded lines, healing each broken one once.
mf-verify-all:
	@for module in $(MF_MODULES); do \
		$(MAKE) --no-print-directory mf-verify-module MF_VERIFY_MODULE="$$module" || exit $$?; \
	done

# Print the recorded module-set VERSION plus a short hash of the cache record,
# so two machines can be compared at a glance. Local-only; no network.
modules-version:
	@version=$$(cat "$(MF_MODULES_ROOT)VERSION" 2>/dev/null || echo '?'); \
	if [ -f "$(MF_VERIFY_HASH_FILE)" ]; then \
	  if command -v sha256sum >/dev/null 2>&1; then h=$$(sha256sum "$(MF_VERIFY_HASH_FILE)" | cut -c1-12); \
	  elif command -v shasum >/dev/null 2>&1; then h=$$(shasum -a 256 "$(MF_VERIFY_HASH_FILE)" | cut -c1-12); \
	  else h='?'; fi; \
	else h='(no cache)'; fi; \
	echo "modules-version: $$version $$h"

# Explicitly re-fetch every cached published module with --force and print the
# version transition. Never a prerequisite of any other target: updates are
# explicit by design (no silent auto-updates). Local-only modules (absent from
# the published manifest) are skipped.
modules-update:
	@old=$$(cat "$(MF_MODULES_ROOT)VERSION" 2>/dev/null || echo '?'); \
	base="$${MAKEFILES_BASE_URL:-https://darianbr.github.io/makefiles/modules}"; \
	fetchurl="$${base%/modules}/fetch"; \
	tmp=$$(mktemp -d "$${TMPDIR:-/tmp}/makefiles-update.XXXXXXXX") || exit 1; \
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM; \
	manifest="$(MF_MODULES_ROOT)manifest.txt"; \
	modules=''; \
	if [ -f "$$manifest" ]; then \
	  # Unquoted on purpose: module names are validated to [a-zA-Z0-9_-], so \
	  # word-splitting the directory list is safe and required. \
	  for d in $$(cd "$(MF_MODULES_ROOT)" && LC_ALL=C ls -d */ 2>/dev/null); do \
	    m=$${d%/}; \
	    if [ -f "$(MF_MODULES_ROOT)$$m/Makefile" ] && grep -q "^$$m/Makefile" "$$manifest"; then modules="$$modules $$m"; fi; \
	  done; \
	fi; \
	if [ -z "$$modules" ]; then echo 'makefiles: no cached published modules to update' >&2; exit 1; fi; \
	for m in $$modules; do \
	  rc=0; curl -sf --max-time "$${MAKEFILES_FETCH_MAX_TIME:-30}" --connect-timeout "$${MAKEFILES_FETCH_CONNECT_TIMEOUT:-10}" "$$fetchurl" -o "$$tmp/fetch" || rc=$$?; \
	  if [ $$rc -eq 0 ]; then bash "$$tmp/fetch" "$$m" --force || rc=$$?; fi; \
	  if [ $$rc -ne 0 ]; then echo "makefiles: failed to update module '$$m' (exit $$rc)" >&2; exit 1; fi; \
	done; \
	new=$$(cat "$(MF_MODULES_ROOT)VERSION" 2>/dev/null || echo '?'); \
	echo "modules-update: $$old -> $$new"

# GNU Make remakes included makefiles before running goals. If verification
# repairs files, change the stamp's timestamp so Make restarts and reparses the
# repaired recipes instead of executing the already-parsed damaged recipes.
.PHONY: mf-check-cache
mf-check-cache:
.makefiles/.verified-cache.mk: mf-check-cache
	@tmp=$$(mktemp -d "$${TMPDIR:-/tmp}/makefiles-stamp.XXXXXXXX") || exit 1; \
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM; \
	if [ -f "$(MF_VERIFY_HASH_FILE)" ]; then cp "$(MF_VERIFY_HASH_FILE)" "$$tmp/before"; fi; \
	MF_VERIFY_REPAIRED_MARKER="$$tmp/repaired" $(MAKE) --no-print-directory mf-verify-all || exit $$?; \
	if [ ! -f "$@" ] || [ -f "$$tmp/repaired" ] || ! cmp -s "$$tmp/before" "$(MF_VERIFY_HASH_FILE)"; then \
		if [ -f "$@" ] && grep -q '^# one$$' "$@"; then \
			printf '%s\n' '# two' > "$@"; touch -t 200201010000 "$@"; \
		else \
			printf '%s\n' '# one' > "$@"; touch -t 200101010000 "$@"; \
		fi; \
	fi

# Only install the include for registered aggregate targets; arbitrary
# consumer targets may use single-colon rules and must not be redefined here.
define mf_verify_register
ifeq ($$(strip $$(MF_SCOPED_MODULE)),)
ifeq ($$(words $$(MAKECMDGOALS)),1)
ifeq ($$(MF_VERIFY_GATE_INSTALLED),)
ifneq ($$(filter $$(MAKECMDGOALS),$(filter-out help clean,$(1))),)
MF_VERIFY_GATE_INSTALLED := 1
include .makefiles/.verified-cache.mk
endif
endif
endif
endif
endef

endif
