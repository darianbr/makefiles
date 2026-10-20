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

# Prefer npm ci for lockfile-driven installs; fall back to npm install when
# only package.json is present so first-time projects can bootstrap.
install::
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(NPM)" >/dev/null 2>&1); then \
		echo "[npm] npm executable not found: $(NPM)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)package.json" ]; then \
		echo "[npm] package.json not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	else \
		if [ -f "$(MF_PROJECT_ROOT)package-lock.json" ] || [ -f "$(MF_PROJECT_ROOT)npm-shrinkwrap.json" ]; then \
			echo "[npm] install target invoked (npm ci)"; \
			cd "$(MF_PROJECT_ROOT)" && "$(NPM)" ci $(NPM_INSTALL_ARGS); \
		else \
			echo "[npm] no lockfile found; install target invoked (npm install)"; \
			cd "$(MF_PROJECT_ROOT)" && "$(NPM)" install $(NPM_INSTALL_ARGS); \
		fi; \
	fi

# Remove conventional generated dependency/build directories only. Lockfiles
# and source files are not part of this list and are left untouched.
clean::
	@cd "$(MF_PROJECT_ROOT)" && \
	for artefact in $(NPM_CLEAN_DIRS); do \
		if [ -d "$$artefact" ]; then \
			echo "[npm] removing $$artefact"; \
			rm -rf -- "$$artefact"; \
		fi; \
	done