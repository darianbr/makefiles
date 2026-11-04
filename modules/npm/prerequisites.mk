#
# Filename: modules/npm/prerequisites.mk
# Last edited: 2026-11-04 12:15:45
# Description: npm executable and package manifest prerequisite checks.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/npm/prerequisites.mk.)
endif

ifndef MF_NPM_PREREQUISITES_INCLUDED
MF_NPM_PREREQUISITES_INCLUDED := 1

MF_NPM_STALE_MODE ?= auto
MF_NPM_INSTALL_STAMP ?= $(MF_PROJECT_ROOT)node_modules/.mf-install.stamp
MF_NPM_LOCKFILE := $(firstword $(wildcard $(MF_PROJECT_ROOT)package-lock.json $(MF_PROJECT_ROOT)npm-shrinkwrap.json))
MF_NPM_INSTALL_STAMP_DEPS := $(MF_PROJECT_ROOT)package.json $(MF_NPM_LOCKFILE)

.PHONY: npm-prerequisites

npm-prerequisites:
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(NPM)" >/dev/null 2>&1); then \
		echo "[npm] npm executable not found: $(NPM)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)package.json" ]; then \
		echo "[npm] package.json not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	fi

$(MF_NPM_INSTALL_STAMP): $(MF_NPM_INSTALL_STAMP_DEPS) | npm-prerequisites
	@lockfile=""; \
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
	touch "$(MF_NPM_INSTALL_STAMP)"

endif
