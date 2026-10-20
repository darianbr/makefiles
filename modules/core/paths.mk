#
# Filename: modules/core/paths.mk
# Last edited: 2026-10-20 18:10:00
# Description: Shared path and state variables for module entry Makefiles.
#

ifndef MF_ROOT_ENTRY
$(error MF_ROOT_ENTRY is not set. Include modules/Makefile before using modules/core/paths.mk.)
endif

MF_MODULES_ROOT := $(dir $(abspath $(MF_ROOT_ENTRY)))
MF_MAKEFILES_ROOT := $(dir $(abspath $(MF_MODULES_ROOT)))
MF_TOOLS_ROOT := $(MF_MAKEFILES_ROOT)tools/
MF_PROJECT_ROOT := $(dir $(abspath $(MF_MAKEFILES_ROOT)))
MF_CACHE_ROOT := $(MF_MAKEFILES_ROOT)cache/

MF_MODULES :=