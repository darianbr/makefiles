#
# Filename: modules/docker/Makefile
# Last edited: 2026-10-20 18:10:00
# Description: Docker module controller that registers targets and includes recipes.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/docker/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/docker/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),echopath clean))

-include .makefiles/modules/docker/targets.mk
