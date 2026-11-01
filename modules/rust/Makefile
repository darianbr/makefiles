#
# Filename: modules/rust/Makefile
# Last edited: 2026-10-31 17:50:26
# Description: Rust module controller that registers targets and includes recipes.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/rust/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/rust/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),echopath build test clippy fmt clean))

CARGO ?= cargo
CARGO_BUILD_ARGS ?=
CARGO_TEST_ARGS ?=
CARGO_CLIPPY_ARGS ?=
CARGO_FMT_ARGS ?=
# Default target directory; the effective value is resolved at runtime from
# CARGO_TARGET_DIR (environment or .cargo/config.toml) when set.
CARGO_TARGET_DIR ?= target

-include .makefiles/modules/rust/targets.mk
