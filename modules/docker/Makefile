#
# Filename: modules/docker/Makefile
# Last edited: 2026-10-01 13:05:25
# Description: Docker module entry targets for container lifecycle tasks.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/docker/Makefile.)
endif

echopath::
	@echo "Docker module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo ""

.PHONY: clean
clean::
	@echo "[docker] clean target invoked"