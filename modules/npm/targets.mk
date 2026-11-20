#
# Filename: modules/npm/targets.mk
# Last edited: 2026-11-04 12:15:45
# Description: npm module target recipes.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/npm/targets.mk.)
endif

ifndef MF_NPM_TARGETS_INCLUDED
MF_NPM_TARGETS_INCLUDED := 1

.PHONY: help install clean

install:: $(MF_NPM_INSTALL_STAMP)
	@echo "[npm] install target up to date"

# Remove conventional generated dependency/build directories only. Lockfiles
# and source files are not part of this list and are left untouched.
clean::
	@cd "$(MF_PROJECT_ROOT)" || exit $$?; \
	found=0; \
	for artefact in $(NPM_CLEAN_DIRS); do \
		if [ -d "$$artefact" ]; then \
			found=1; \
			echo "[npm] removing $$artefact"; \
			rm -rf -- "$$artefact"; \
		fi; \
	done; \
	if [ "$$found" -eq 0 ]; then \
		echo "[npm] clean skipped (no generated directories found)"; \
	fi

endif
