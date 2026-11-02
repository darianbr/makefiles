#
# Filename: modules/npm/Makefile
# Last edited: 2026-11-02 18:26:11
# Description: npm module controller that registers targets and includes recipes.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/npm/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/npm/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),echopath install clean help))

NPM ?= npm
NPM_INSTALL_ARGS ?=
NPM_CLEAN_DIRS ?= node_modules dist build coverage .next .nuxt .output

-include .makefiles/modules/npm/prerequisites.mk
-include .makefiles/modules/npm/targets.mk

