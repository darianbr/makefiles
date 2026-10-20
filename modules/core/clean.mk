#
# Filename: modules/core/clean.mk
# Last edited: 2026-10-20 18:10:00
# Description: Shared base clean behavior for imported module sets.
#

ifneq ($(strip $(MF_SCOPED_MODULE)),)
# A scoped recursive make must not run the shared root's aggregate-only
# recipes. The selected module entry point supplies the requested target.
else
.PHONY: clean
clean::
	@if [ -d "$(MF_MAKEFILES_ROOT)" ]; then \
		echo "[base] clean makefiles folder"; \
		rm -rf "$(MF_MAKEFILES_ROOT)"; \
	else \
		echo "[base] skipping makefiles folder (not found)"; \
	fi
	@if [ -d "$(MF_CACHE_ROOT)" ]; then \
		echo "[base] clean cache folder"; \
		rm -rf "$(MF_CACHE_ROOT)"; \
	else \
		echo "[base] skipping cache folder (not found)"; \
	fi
	@rmdir "$(MF_PROJECT_ROOT).cache" 2>/dev/null || true
endif