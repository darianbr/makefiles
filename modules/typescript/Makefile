#
# Filename: modules/typescript/Makefile
# Last edited: 2026-11-02 18:26:11
# Description: TypeScript module controller that registers targets and includes recipes.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/typescript/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/typescript/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),echopath build test clean install help))

NPM ?= npm
TSC ?= $(MF_PROJECT_ROOT)node_modules/.bin/tsc
TSC_PROJECT ?= tsconfig.json
TSC_BUILD_OUT_DIR ?= build/typescript
TSC_BUILD_ARGS ?= -p $(TSC_PROJECT) --outDir $(TSC_BUILD_OUT_DIR)
TSC_TEST_ARGS ?= --noEmit -p $(TSC_PROJECT)

-include .makefiles/modules/typescript/prerequisites.mk
-include .makefiles/modules/typescript/targets.mk
