#
# Filename: modules/wtree/Makefile
# Last edited: 2026-11-20
# Description: Register the local worktree proxy module.
#

MF_WTREE_CORE_FILES := .makefiles/modules/Makefile $(addprefix .makefiles/modules/core/,clean.mk discover-common.sh dispatch.mk help.mk paths.mk registry.mk remove-with-guardrails.sh verify.mk)
MF_WTREE_MISSING_CORE := $(foreach file,$(MF_WTREE_CORE_FILES),$(if $(shell test -s $(file) && test -f $(file) && test ! -L $(file) && printf yes),,$(file)))
ifneq ($(strip $(MF_WTREE_MISSING_CORE)),)
$(error wtree: Makefiles core is missing or invalid: $(MF_WTREE_MISSING_CORE))
endif

-include .makefiles/modules/Makefile

# The shared dispatch gate uses /bin/true, which is absent on macOS.
ifneq ($(MF_LEGACY_GOALS),1)
ifeq ($(words $(MAKECMDGOALS)),2)
$(MF_DISPATCH_TARGET): SHELL := /usr/bin/true
# GNU Make 3.81 can run outer prerequisites before the old-file flag under
# -j. Only this outer make is serialized; recursive makes retain parallelism.
.NOTPARALLEL:
endif
endif

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/wtree/Makefile.)
endif
ifndef mf_register_module
$(error wtree: Makefiles module registry is missing or invalid)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/wtree/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),clean install help up down status))

-include .makefiles/modules/wtree/prerequisites.mk
-include .makefiles/modules/wtree/targets.mk