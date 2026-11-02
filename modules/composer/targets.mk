#
# Filename: modules/composer/targets.mk
# Last edited: 2026-11-02 18:26:33
# Description: Composer module target recipes.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/composer/targets.mk.)
endif

ifndef MF_COMPOSER_TARGETS_INCLUDED
MF_COMPOSER_TARGETS_INCLUDED := 1

.PHONY: help install clean install-composer-binary

help::
	@printf '%s\n' 'composer targets: $(MF_MODULE_TARGETS_composer)'

echopath::
	@echo "Composer module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo ""

install:: composer-prerequisites $(MF_COMPOSER_TARGET)
	@echo "[composer] install target invoked"
	"$(PHP)" "$(COMPOSER)" install --working-dir="$(MF_PROJECT_ROOT)"

# Clean vendor directory if it exists.
clean::
	@if [ -d "$(MF_PROJECT_ROOT)vendor" ] && [ -f "$(MF_PROJECT_ROOT)composer.lock" ]; then \
		echo "[composer] clean target invoked"; \
		rm -rf "$(MF_PROJECT_ROOT)vendor"; \
	else \
		echo "[composer] clean target skipped (requires vendor/ and composer.lock)"; \
	fi

# Install Composer if it doesn't exist.
$(MF_COMPOSER_TARGET):
	@if [ -f "$(COMPOSER)" ]; then \
		echo "[composer] composer binary already present"; \
	else \
		$(MAKE) --no-print-directory install-composer-binary && \
		echo "[composer] composer binary is installed"; \
	fi

install-composer-binary: composer-prerequisites
	@set -eu; \
	mkdir -p "$(MF_TOOLS_ROOT)"; \
	installer="$(MF_TOOLS_ROOT)composer-setup.php"; \
	signature="$(MF_TOOLS_ROOT)composer-setup.sig"; \
	trap 'rm -f "$$installer" "$$signature"' EXIT; \
	curl -fsSL https://getcomposer.org/installer -o "$$installer"; \
	curl -fsSL https://composer.github.io/installer.sig -o "$$signature"; \
	expected_sig=$$(cat "$$signature"); \
	actual_sig=$$("$(PHP)" -r 'echo hash_file("sha384", $$argv[1]);' "$$installer"); \
	if [ "$$expected_sig" != "$$actual_sig" ]; then \
		echo "ERROR: Invalid installer signature" >&2; \
		exit 1; \
	fi; \
	"$(PHP)" "$$installer" --install-dir="$(MF_TOOLS_ROOT)" --filename=composer.phar

endif
