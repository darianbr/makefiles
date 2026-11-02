#
# Filename: modules/docker/Makefile
# Last edited: 2026-11-02 18:26:11
# Description: Docker module controller that registers targets and includes recipes.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/docker/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/docker/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),echopath clean install help))

-include .makefiles/modules/docker/prerequisites.mk
-include .makefiles/modules/docker/targets.mk
