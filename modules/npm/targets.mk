#
# Filename: modules/npm/targets.mk
# Last edited: 2026-11-02 18:48:48
# Description: npm module target recipes.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/npm/targets.mk.)
endif

ifndef MF_NPM_TARGETS_INCLUDED
MF_NPM_TARGETS_INCLUDED := 1

.PHONY: help echopath install clean

help::
	@printf '%s\n' 'npm targets: $(MF_MODULE_TARGETS_npm)'

echopath::
	@echo "npm module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo "NPM: $(NPM)"
	@echo ""

# Prefer npm ci for lockfile-driven installs; fall back to npm install when
# only package.json is present so first-time projects can bootstrap.
install:: npm-prerequisites
	@if [ -f "$(MF_PROJECT_ROOT)package-lock.json" ] || [ -f "$(MF_PROJECT_ROOT)npm-shrinkwrap.json" ]; then \
		echo "[npm] install target invoked (npm ci)"; \
		cd "$(MF_PROJECT_ROOT)" && "$(NPM)" ci $(NPM_INSTALL_ARGS); \
	else \
		echo "[npm] no lockfile found; install target invoked (npm install)"; \
		cd "$(MF_PROJECT_ROOT)" && "$(NPM)" install $(NPM_INSTALL_ARGS); \
	fi

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
