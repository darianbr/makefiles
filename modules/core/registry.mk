#
# Filename: modules/core/registry.mk
# Last edited: 2026-10-20 18:10:00
# Description: Shared module registration helpers used by module entrypoints.
#

# Module entry points call this after including the root. Keeping registration
# at the entry point means only explicitly imported modules are dispatchable;
# cached but unreferenced module directories are ignored.
mf_module_name = $(notdir $(patsubst %/,%,$(dir $(1))))
define mf_register_module
MF_MODULES += $(call mf_module_name,$(1))
MF_MODULE_ENTRY_$(call mf_module_name,$(1)) := $(1)
MF_MODULE_TARGETS_$(call mf_module_name,$(1)) := $(sort $(2))
endef