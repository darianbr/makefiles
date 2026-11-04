#
# Filename: modules/vitest/Makefile
# Last edited: 2026-11-04 20:19:22
# Description: Vitest module controller that registers targets and includes recipes.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/vitest/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/vitest/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),test coverage coverage-open clean install help))

NPM ?= npm
MF_VITEST_DEFAULT_BIN := $(MF_PROJECT_ROOT)node_modules/.bin/vitest
VITEST_BIN ?= $(MF_VITEST_DEFAULT_BIN)
ifeq ($(origin VITEST),command line)
VITEST_BIN := $(VITEST)
endif
VITEST_ARGS ?=
VITEST_COVERAGE_DIR ?= coverage/vitest
MF_VITEST_COVERAGE_INDEX_CACHE_PATH := $(MF_CACHE_ROOT)vitest-coverage-index

-include .makefiles/modules/vitest/prerequisites.mk
-include .makefiles/modules/vitest/targets.mk
