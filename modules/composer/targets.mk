#
# Filename: modules/composer/targets.mk
# Last edited: 2026-10-20 18:10:00
# Description: Composer module target recipes.
#

.PHONY: echopath install clean install-composer-binary

echopath::
	@echo "Composer module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo ""

install:: $(MF_COMPOSER_TARGET)
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

# Install composer if it doesn't exist.
$(MF_COMPOSER_TARGET):
	@if [ -f "$(COMPOSER)" ]; then \
		echo "[composer] composer binary already present"; \
	else \
		$(MAKE) --no-print-directory install-composer-binary && \
		echo "[composer] composer binary is installed"; \
	fi