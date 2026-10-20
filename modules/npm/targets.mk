#
# Filename: modules/npm/targets.mk
# Last edited: 2026-10-20 18:10:00
# Description: npm module target recipes.
#

.PHONY: echopath install clean

echopath::
	@echo "npm module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo "NPM: $(NPM)"
	@echo ""

# npm ci consumes the existing npm lockfile without updating it.
install::
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(NPM)" >/dev/null 2>&1); then \
		echo "[npm] npm executable not found: $(NPM)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)package.json" ]; then \
		echo "[npm] package.json not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)package-lock.json" ] && [ ! -f "$(MF_PROJECT_ROOT)npm-shrinkwrap.json" ]; then \
		echo "[npm] package-lock.json or npm-shrinkwrap.json is required; refusing to change dependency resolution" >&2; \
		exit 1; \
	else \
		echo "[npm] install target invoked (npm ci)"; \
		cd "$(MF_PROJECT_ROOT)" && "$(NPM)" ci $(NPM_INSTALL_ARGS); \
	fi

# Remove conventional generated dependency/build directories only. Lockfiles
# and source files are not part of this list and are left untouched.
clean::
	@cd "$(MF_PROJECT_ROOT)" && \
	for artifact in $(NPM_CLEAN_DIRS); do \
		if [ -d "$$artifact" ]; then \
			echo "[npm] removing $$artifact"; \
			rm -rf -- "$$artifact"; \
		fi; \
	done