#
# Filename: modules/typescript/prerequisites.mk
# Last edited: 2026-11-02 18:25:58
# Description: npm, project, and TypeScript compiler prerequisite checks.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/typescript/prerequisites.mk.)
endif

ifndef MF_TYPESCRIPT_PREREQUISITES_INCLUDED
MF_TYPESCRIPT_PREREQUISITES_INCLUDED := 1

.PHONY: typescript-prerequisites

typescript-prerequisites:
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(NPM)" >/dev/null 2>&1); then \
		echo "[typescript] npm executable not found: $(NPM)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)package.json" ]; then \
		echo "[typescript] package.json not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)$(TSC_PROJECT)" ]; then \
		echo "[typescript] project file not found: $(MF_PROJECT_ROOT)$(TSC_PROJECT)" >&2; \
		exit 1; \
	elif [ -f "$(TSC)" ] || (cd "$(MF_PROJECT_ROOT)" && command -v tsc >/dev/null 2>&1); then \
		:; \
	else \
		echo "[typescript] TypeScript executable not found; attempting npm install."; \
		if [ -f "$(MF_MODULES_ROOT)npm/Makefile" ]; then \
			$(MAKE) --no-print-directory npm install || exit $$?; \
		else \
			$(MAKE) --no-print-directory install || exit $$?; \
		fi; \
		if [ -f "$(TSC)" ] || (cd "$(MF_PROJECT_ROOT)" && command -v tsc >/dev/null 2>&1); then \
			:; \
		else \
			echo "[typescript] TypeScript executable is still missing: $(TSC)" >&2; \
			exit 1; \
		fi; \
	fi

endif
