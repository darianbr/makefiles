#
# Filename: modules/composer/prerequisites.mk
# Last edited: 2026-11-04 12:15:45
# Description: Composer and PHP executable prerequisite checks.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/composer/prerequisites.mk.)
endif

ifndef MF_COMPOSER_PREREQUISITES_INCLUDED
MF_COMPOSER_PREREQUISITES_INCLUDED := 1

MF_COMPOSER_STALE_MODE ?= auto
MF_COMPOSER_INSTALL_STAMP ?= $(MF_PROJECT_ROOT)vendor/.mf-install.stamp
MF_COMPOSER_LOCKFILE := $(wildcard $(MF_PROJECT_ROOT)composer.lock)
MF_COMPOSER_INSTALL_STAMP_DEPS := $(MF_PROJECT_ROOT)composer.json $(MF_COMPOSER_LOCKFILE)

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

$(MF_COMPOSER_INSTALL_STAMP): $(MF_COMPOSER_INSTALL_STAMP_DEPS) | composer-prerequisites $(MF_COMPOSER_TARGET)
	@if [ ! -f "$(MF_PROJECT_ROOT)composer.json" ]; then \
		echo "[composer] composer.json not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	fi
	@lockfile="$(MF_PROJECT_ROOT)composer.lock"; \
	if [ -f "$$lockfile" ] && [ "$(MF_PROJECT_ROOT)composer.json" -nt "$$lockfile" ]; then \
		case "$(MF_COMPOSER_STALE_MODE)" in \
		fail) \
			echo "[composer] composer.json is newer than composer.lock" >&2; \
			echo "[composer] stale policy is fail. Run composer update --lock to refresh lockfile." >&2; \
			exit 1; \
			;; \
		warn) \
			echo "[composer] warning: composer.json is newer than composer.lock" >&2; \
			echo "[composer] continuing with composer install due to MF_COMPOSER_STALE_MODE=warn" >&2; \
			;; \
		auto) \
			echo "[composer] composer.json is newer than composer.lock; refreshing lockfile"; \
			"$(PHP)" "$(COMPOSER)" update --lock --working-dir="$(MF_PROJECT_ROOT)"; \
			;; \
		*) \
			echo "[composer] unknown MF_COMPOSER_STALE_MODE='$(MF_COMPOSER_STALE_MODE)' (expected auto|warn|fail)" >&2; \
			exit 1; \
			;; \
		esac; \
	fi; \
	echo "[composer] install target invoked"; \
	"$(PHP)" "$(COMPOSER)" install --working-dir="$(MF_PROJECT_ROOT)"; \
	mkdir -p "$(dir $(MF_COMPOSER_INSTALL_STAMP))"; \
	touch "$(MF_COMPOSER_INSTALL_STAMP)"

endif
