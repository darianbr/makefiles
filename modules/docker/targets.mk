#
# Filename: modules/docker/targets.mk
# Last edited: 2026-11-04 20:19:22
# Description: Docker module target recipes.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/docker/targets.mk.)
endif

ifndef MF_DOCKER_TARGETS_INCLUDED
MF_DOCKER_TARGETS_INCLUDED := 1

.PHONY: help clean install

install:: docker-prerequisites
	@echo "[docker] install target invoked (project services and images are project-specific)"

clean::
	@echo "[docker] clean is a no-op (project containers and images are project-specific)"

endif
