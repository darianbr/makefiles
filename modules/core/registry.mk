#
# Filename: modules/core/registry.mk
# Last edited: 2026-11-04 20:19:22
# Description: Shared module registration helpers used by module entrypoints.
#

# Module entry points call this after including the root. Keeping registration
# at the entry point means only explicitly imported modules are dispatchable;
# cached but unreferenced module directories are ignored.
mf_module_name = $(notdir $(patsubst %/,%,$(dir $(1))))
define mf_register_module
$(if $(filter clean,$(2)),,$(error makefiles: module '$(call mf_module_name,$(1))' must register the required target 'clean'))
$(if $(filter install,$(2)),,$(error makefiles: module '$(call mf_module_name,$(1))' must register the required target 'install'))
$(if $(filter help,$(2)),,$(error makefiles: module '$(call mf_module_name,$(1))' must register the required target 'help'))
$(if $(filter echopath,$(2)),$(error makefiles: module '$(call mf_module_name,$(1))' must replace retired target 'echopath' with 'help'))
$(if $(filter $(words $(2)),$(words $(sort $(2)))),,$(error makefiles: module '$(call mf_module_name,$(1))' has duplicate public target registrations))
MF_MODULES += $(call mf_module_name,$(1))
MF_MODULE_ENTRY_$(call mf_module_name,$(1)) := $(1)
MF_MODULE_TARGETS_$(call mf_module_name,$(1)) := $(sort $(2))
ifeq ($$(MF_SCOPED_MODULE),$(call mf_module_name,$(1)))
.PHONY: help
help:
	@printf '%s\n' \
		'$(call mf_module_name,$(1)) module' \
		'Usage: make $(call mf_module_name,$(1)) <target>' \
		'Available targets: $$(MF_MODULE_TARGETS_$(call mf_module_name,$(1)))'
endif
endef