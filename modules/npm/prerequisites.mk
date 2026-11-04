#
# Filename: modules/npm/prerequisites.mk
# Last edited: 2026-11-02 18:25:58
# Description: npm executable and package manifest prerequisite checks.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/npm/prerequisites.mk.)
endif

ifndef MF_NPM_PREREQUISITES_INCLUDED
MF_NPM_PREREQUISITES_INCLUDED := 1

.PHONY: npm-prerequisites

npm-prerequisites:
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(NPM)" >/dev/null 2>&1); then \
		echo "[npm] npm executable not found: $(NPM)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)package.json" ]; then \
		echo "[npm] package.json not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	fi

endif
