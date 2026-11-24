#
# Filename: modules/core/verify.mk
# Last edited: 2026-11-22
# Description: Lazy cache verification with one-shot self-heal for corrupted files.
#

# The cache records a sha256sum-verifiable hash of every file after each fetch
# (see fetch). Verification is local-only and sub-second on the happy path: a
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
# <site>/modules. Strip the trailing /modules to derive the site root.
MF_VERIFY_SITE_ROOT := $(patsubst %/modules,$(MAKEFILES_BASE_URL),$(if $(filter %/modules,$(MAKEFILES_BASE_URL)),$(MAKEFILES_BASE_URL),$(MAKEFILES_BASE_URL)/modules))

.PHONY: mf-verify-module mf-verify-all

# Verify one module's recorded lines (plus the shared root/core files every
# module depends on). MF_VERIFY_MODULE selects the module; on mismatch or a
# missing record, re-fetch that module once and verify again.
mf-verify-module:
	@module="$(MF_VERIFY_MODULE)"; \
	hashfile="$(MF_VERIFY_HASH_FILE)"; \
	manifest="$(MF_MODULES_ROOT)manifest.txt"; \
	if [ -z "$$module" ]; then echo 'makefiles: mf-verify-module requires MF_VERIFY_MODULE' >&2; exit 1; fi; \
	if command -v sha256sum >/dev/null 2>&1; then hashcheck="sha256sum -c --quiet"; \
	elif command -v shasum >/dev/null 2>&1; then hashcheck="shasum -a 256 -c"; \
	else echo 'makefiles: sha256sum or shasum is required to verify the module cache' >&2; exit 1; fi; \
	verified=0; bad=''; published=0; \
	if [ -f "$$hashfile" ]; then \
		lines=$$(cd "$(MF_MODULES_ROOT)" && awk -v m="$$module" '$$2 == "Makefile" || $$2 == "VERSION" || index($$2, "core/") == 1 || index($$2, m "/") == 1' "$$hashfile"); \
		if [ -n "$$lines" ]; then \
			printf '%s\n' "$$lines" > /tmp/.mf-verify.$$; \
			bad=$$(cd "$(MF_MODULES_ROOT)" && $$hashcheck /tmp/.mf-verify.$$ 2>&1); rc=$$?; rm -f /tmp/.mf-verify.$$; \
			[ $$rc -eq 0 ] && verified=1; \
		fi; \
	else bad='missing hash record'; fi; \
	if [ $$verified -eq 0 ] && [ -f "$$manifest" ] && grep -q "^$$module/" "$$manifest"; then published=1; fi; \
	if [ $$verified -eq 0 ] && [ $$published -eq 0 ]; then exit 0; fi; \
	if [ $$verified -eq 0 ]; then \
		offending=$$(printf '%s\n' "$$bad" | grep FAILED | head -n 1 | cut -d: -f1); \
		echo "makefiles: cache verification failed for $$module ($${offending:-$$module}); re-fetching"; \
		rc=0; curl -sf --max-time "$${MAKEFILES_FETCH_MAX_TIME:-30}" --connect-timeout "$${MAKEFILES_FETCH_CONNECT_TIMEOUT:-10}" "$(MF_VERIFY_SITE_ROOT)/fetch" | bash /dev/stdin "$$module" --force || rc=$$?; \
		if [ $$rc -ne 0 ]; then echo "makefiles: cache verification failed for $${offending:-$$module} in module '$$module'; re-fetch also failed (curl exit $$rc)" >&2; exit 1; fi; \
		if [ ! -f "$$hashfile" ] || [ -z "$$(awk -v m="$$module" '$$2 == "Makefile" || $$2 == "VERSION" || index($$2, "core/") == 1 || index($$2, m "/") == 1' "$$hashfile")" ]; then echo "makefiles: cache verification failed for module '$$module'; re-fetch produced no recorded lines (module not in published manifest?)" >&2; exit 1; fi; \
		lines=$$(cd "$(MF_MODULES_ROOT)" && awk -v m="$$module" '$$2 == "Makefile" || $$2 == "VERSION" || index($$2, "core/") == 1 || index($$2, m "/") == 1' "$$hashfile"); \
		printf '%s\n' "$$lines" > /tmp/.mf-verify.$$; \
		bad=$$(cd "$(MF_MODULES_ROOT)" && $$hashcheck /tmp/.mf-verify.$$ 2>&1); rc=$$?; rm -f /tmp/.mf-verify.$$; \
		if [ $$rc -ne 0 ]; then echo "makefiles: cache verification failed for $$(printf '%s\n' "$$bad" | grep FAILED | head -n 1 | cut -d: -f1) in module '$$module'; re-fetch also failed" >&2; exit 1; fi; \
	fi

# Verify every imported module's recorded lines, healing each broken one once.
mf-verify-all:
	@for module in $(MF_MODULES); do \
		$(MAKE) --no-print-directory mf-verify-module MF_VERIFY_MODULE="$$module" || exit $$?; \
	done

# Install the gate only for registered public targets. Arbitrary consumer
# targets may use single-colon rules and must not be redefined here. Each
# module registers before including its target recipes; serialize the outer
# make so double-colon rules cannot race the verification under -j.
define mf_verify_register
ifeq ($$(strip $$(MF_SCOPED_MODULE)),)
ifeq ($$(words $$(MAKECMDGOALS)),1)
ifeq ($$(MF_VERIFY_GATE_INSTALLED),)
ifneq ($$(filter $$(MAKECMDGOALS),$(filter-out help clean,$(1))),)
MF_VERIFY_GATE_INSTALLED := 1
.NOTPARALLEL:
$$(MAKECMDGOALS)::
	@$$(MAKE) --no-print-directory mf-verify-all
endif
endif
endif
endif
endef

endif
