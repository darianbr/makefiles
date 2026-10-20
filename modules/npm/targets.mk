#
# Filename: modules/npm/targets.mk
# Last edited: 2026-10-20 18:10:00
# Description: npm module target recipes.
#

MF_NPM_LOCKFILE := $(firstword $(wildcard $(MF_PROJECT_ROOT)package-lock.json $(MF_PROJECT_ROOT)npm-shrinkwrap.json))
MF_NPM_INSTALL_STAMP_DEPS := $(MF_PROJECT_ROOT)package.json $(MF_NPM_LOCKFILE)

.PHONY: echopath install clean

echopath::
	@echo "npm module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo "NPM: $(NPM)"
	@echo ""

install:: $(MF_NPM_INSTALL_STAMP)
	@echo "[npm] install target up to date"

# Install dependencies when package manifests/lockfiles are newer than the
# install stamp. This uses Make's native timestamp tracking for stale detection.
$(MF_NPM_INSTALL_STAMP): $(MF_NPM_INSTALL_STAMP_DEPS)
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(NPM)" >/dev/null 2>&1); then \
		echo "[npm] npm executable not found: $(NPM)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)package.json" ]; then \
		echo "[npm] package.json not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	else \
		lockfile=""; \
		if [ -f "$(MF_PROJECT_ROOT)package-lock.json" ]; then \
			lockfile="$(MF_PROJECT_ROOT)package-lock.json"; \
		elif [ -f "$(MF_PROJECT_ROOT)npm-shrinkwrap.json" ]; then \
			lockfile="$(MF_PROJECT_ROOT)npm-shrinkwrap.json"; \
		fi; \
		install_mode="install"; \
		if [ -n "$$lockfile" ]; then \
			install_mode="ci"; \
			if [ "$(MF_PROJECT_ROOT)package.json" -nt "$$lockfile" ]; then \
				case "$(MF_NPM_STALE_MODE)" in \
				fail) \
					echo "[npm] package.json is newer than $${lockfile#$(MF_PROJECT_ROOT)}" >&2; \
					echo "[npm] stale policy is fail. Run npm install to refresh lockfile." >&2; \
					exit 1; \
					;; \
				warn) \
					echo "[npm] warning: package.json is newer than $${lockfile#$(MF_PROJECT_ROOT)}" >&2; \
					echo "[npm] continuing with npm ci due to MF_NPM_STALE_MODE=warn" >&2; \
					;; \
				auto) \
					echo "[npm] package.json is newer than $${lockfile#$(MF_PROJECT_ROOT)}; using npm install to refresh lockfile"; \
					install_mode="install"; \
					;; \
				*) \
					echo "[npm] unknown MF_NPM_STALE_MODE='$(MF_NPM_STALE_MODE)' (expected auto|warn|fail)" >&2; \
					exit 1; \
					;; \
				esac; \
			fi; \
		else \
			echo "[npm] no lockfile found; using npm install"; \
		fi; \
		echo "[npm] install target invoked (npm $$install_mode)"; \
		cd "$(MF_PROJECT_ROOT)" && "$(NPM)" "$$install_mode" $(NPM_INSTALL_ARGS); \
		mkdir -p "$(dir $(MF_NPM_INSTALL_STAMP))"; \
		touch "$(MF_NPM_INSTALL_STAMP)"; \
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