#
# Filename: modules/composer/Makefile
# Last edited: 2025-12-15 09:12:50
# Description: Composer module entry targets for install and clean workflows.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/composer/Makefile.)
endif

-include .makefiles/modules/Makefile
-include .makefiles/modules/composer/install-binary.mk

COMPOSER := $(MF_TOOLS_ROOT)composer.phar

echopath::
	@echo "Composer module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo ""

install:: $(COMPOSER)
	@echo "[composer] install target invoked"
	php $(COMPOSER) install --working-dir=$(MF_PROJECT_ROOT)

# Clean vendor directory if it exists
clean::
	@if [ -d "$(MF_PROJECT_ROOT)vendor" ] && [ -f "$(MF_PROJECT_ROOT)composer.lock" ]; then \
		echo "[composer] clean target invoked"; \
		rm -rf "$(MF_PROJECT_ROOT)vendor"; \
	else \
		echo "[composer] clean target skipped, no vendor directory and composer.lock found"; \
	fi

# Install composer if it doesn't exist
$(COMPOSER): 
	@if [ -f "$(COMPOSER)" ]; then \
		echo "[composer] composer binary already present"; \
	else \
		$(MAKE) install-composer-binary && \
		echo "[composer] composer binary is installed"; \
	fi