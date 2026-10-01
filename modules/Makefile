#
# Filename: modules/Makefile
# Last edited: 2026-10-01 13:05:25
# Description: Root module makefile providing shared paths and clean helpers.
#

MF_MODULES_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
MF_MAKEFILES_ROOT := $(dir $(abspath $(MF_MODULES_ROOT)))
MF_TOOLS_ROOT := $(MF_MAKEFILES_ROOT)tools/
MF_PROJECT_ROOT := $(dir $(abspath $(MF_MAKEFILES_ROOT)))

.PHONY: clean
clean:: 
	@if [ -d "$(MF_MAKEFILES_ROOT)" ]; then \
        echo "[base] clean makefiles folder"; \
        rm -rf "$(MF_MAKEFILES_ROOT)"; \
    else \
        echo "[base] skipping makefiles folder (not found)"; \
    fi