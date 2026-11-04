#
# Filename: modules/docker/prerequisites.mk
# Last edited: 2026-11-02 18:25:58
# Description: Docker CLI prerequisite check for project-specific workflows.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/docker/prerequisites.mk.)
endif

ifndef MF_DOCKER_PREREQUISITES_INCLUDED
MF_DOCKER_PREREQUISITES_INCLUDED := 1

DOCKER ?= docker

.PHONY: docker-prerequisites

docker-prerequisites:
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(DOCKER)" >/dev/null 2>&1); then \
		echo "[docker] Docker executable not found: $(DOCKER)" >&2; \
		echo "[docker] Install Docker or invoke make with DOCKER=/path/to/docker." >&2; \
		exit 1; \
	fi

endif
