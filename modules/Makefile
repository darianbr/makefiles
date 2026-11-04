#
# Filename: modules/Makefile
# Last edited: 2026-11-04 20:19:22
# Description: Root module controller that composes shared include logic.
#

ifndef MF_ROOT_INCLUDED
MF_ROOT_INCLUDED := 1
MF_ROOT_ENTRY := $(lastword $(MAKEFILE_LIST))

-include .makefiles/modules/core/paths.mk
-include .makefiles/modules/core/registry.mk
-include .makefiles/modules/core/dispatch.mk
-include .makefiles/modules/core/clean.mk
-include .makefiles/modules/core/help.mk

endif
