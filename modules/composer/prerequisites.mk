#
# Filename: modules/composer/prerequisites.mk
# Last edited: 2026-11-02 18:25:58
# Description: Composer and PHP executable prerequisite checks.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/composer/prerequisites.mk.)
endif

ifndef MF_COMPOSER_PREREQUISITES_INCLUDED
MF_COMPOSER_PREREQUISITES_INCLUDED := 1

.PHONY: composer-prerequisites

composer-prerequisites:
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(PHP)" >/dev/null 2>&1); then \
		echo "[composer] PHP executable not found: $(PHP)" >&2; \
		echo "[composer] Install PHP or invoke make with PHP=/path/to/php." >&2; \
		exit 1; \
	elif [ ! -f "$(COMPOSER)" ] && ! command -v curl >/dev/null 2>&1; then \
		echo "[composer] curl is required to download the Composer binary." >&2; \
		exit 1; \
	fi

endif
