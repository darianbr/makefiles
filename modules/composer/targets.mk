#
# Filename: modules/composer/targets.mk
# Last edited: 2026-10-20 18:10:00
# Description: Composer module target recipes.
#

MF_COMPOSER_LOCKFILE := $(wildcard $(MF_PROJECT_ROOT)composer.lock)
MF_COMPOSER_INSTALL_STAMP_DEPS := $(MF_PROJECT_ROOT)composer.json $(MF_COMPOSER_LOCKFILE)

.PHONY: echopath install clean install-composer-binary

echopath::
	@echo "Composer module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo ""

install:: $(MF_COMPOSER_TARGET) $(MF_COMPOSER_INSTALL_STAMP)
	@echo "[composer] install target up to date"

# Install dependencies when composer manifests/lockfiles are newer than the
# install stamp. This uses Make's native timestamp tracking for stale detection.
$(MF_COMPOSER_INSTALL_STAMP): $(MF_COMPOSER_INSTALL_STAMP_DEPS)
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

# Clean vendor directory if it exists.
clean::
	@if [ -d "$(MF_PROJECT_ROOT)vendor" ] && [ -f "$(MF_PROJECT_ROOT)composer.lock" ]; then \
		echo "[composer] clean target invoked"; \
		rm -rf "$(MF_PROJECT_ROOT)vendor"; \
	else \
		echo "[composer] clean target skipped (requires vendor/ and composer.lock)"; \
	fi

# Install composer if it doesn't exist.
$(MF_COMPOSER_TARGET):
	@if [ -f "$(COMPOSER)" ]; then \
		echo "[composer] composer binary already present"; \
	else \
		$(MAKE) --no-print-directory install-composer-binary && \
		echo "[composer] composer binary is installed"; \
	fi