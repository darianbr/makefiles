#
# Filename: modules/Makefile
# Last edited: 2025-12-15 09:08:39
# Description: Root module makefile providing shared paths and clean helpers.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/Makefile.)
endif

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