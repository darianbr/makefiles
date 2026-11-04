#
# Filename: modules/codeception/Makefile
# Last edited: 2026-11-04 20:19:22
# Description: Codeception module controller that registers targets and includes recipes.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/codeception/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/codeception/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),test coverage coverage-open clean install help))

# Codeception is installed by the consuming project's Composer manifest.
# Override CODECEPTION when a project keeps the executable somewhere else.
PHP ?= php
CODECEPTION ?= $(MF_PROJECT_ROOT)vendor/bin/codecept
CODECEPTION_ARGS ?=

-include .makefiles/modules/codeception/prerequisites.mk
-include .makefiles/modules/codeception/targets.mk
