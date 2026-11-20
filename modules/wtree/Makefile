#
# Filename: modules/wtree/Makefile
# Last edited: 2026-11-20
# Description: Register the local worktree proxy module.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/wtree/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/wtree/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),clean install help up down status))

-include .makefiles/modules/wtree/prerequisites.mk
-include .makefiles/modules/wtree/targets.mk