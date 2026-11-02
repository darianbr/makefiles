#
# Filename: modules/docker/targets.mk
# Last edited: 2026-11-02 18:46:28
# Description: Docker module target recipes.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/docker/targets.mk.)
endif

ifndef MF_DOCKER_TARGETS_INCLUDED
MF_DOCKER_TARGETS_INCLUDED := 1

.PHONY: help echopath clean install

help::
	@printf '%s\n' 'docker targets: $(MF_MODULE_TARGETS_docker)'

echopath::
	@echo "Docker module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo ""

install:: docker-prerequisites
	@echo "[docker] install target invoked (project services and images are project-specific)"

clean::
	@echo "[docker] clean is a no-op (project containers and images are project-specific)"

endif
