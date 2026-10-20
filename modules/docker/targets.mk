#
# Filename: modules/docker/targets.mk
# Last edited: 2026-10-20 18:10:00
# Description: Docker module target recipes.
#

.PHONY: echopath clean

echopath::
	@echo "Docker module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo ""

clean::
	@echo "[docker] clean target invoked"