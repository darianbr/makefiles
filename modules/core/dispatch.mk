#
# Filename: modules/core/dispatch.mk
# Last edited: 2026-10-20 18:10:00
# Description: Scoped module dispatch gate for `make <module> <target>`.
#

# Command-line forms are intentionally asymmetric: `make <target>` remains
# aggregate mode for all imported modules, while the exact `make <module>
# <target>` form selects one registered module. GNU Make does not provide a
# post-include hook or a supported way to replace its internal goal list, so
# the first goal becomes a validation/dispatch gate and the second goal is a
# no-op in this outer invocation. The selected module runs in a recursive
# make; one-goal and multi-goal invocations retain normal GNU Make handling.
# Consumers may set MF_DISPATCH_SETUP and MF_DISPATCH_SETUP_PAIRS to run a
# consumer-defined prerequisite target before selected scoped invocations.
ifneq ($(MF_LEGACY_GOALS),1)
ifneq ($(words $(MAKECMDGOALS)),0)
ifeq ($(words $(MAKECMDGOALS)),2)
MF_DISPATCH_MODULE := $(word 1,$(MAKECMDGOALS))
MF_DISPATCH_TARGET := $(word 2,$(MAKECMDGOALS))
MAKEFLAGS += -o $(MF_DISPATCH_TARGET)

.PHONY: $(MF_DISPATCH_MODULE)
# The selected target is run by the recursive make in the gate recipe. A
# target-specific shell keeps its aggregate recipes from running afterwards,
# including recipes supplied by modules that do not know about dispatch. The
# old-file flag also prevents the second goal's prerequisites from being
# rebuilt in the outer invocation; this matters when the selected target has
# prerequisites of its own.
$(MF_DISPATCH_TARGET): SHELL := /bin/true
$(MF_DISPATCH_MODULE)::
	@if [ -z "$(filter $(MF_DISPATCH_MODULE),$(MF_MODULES))" ]; then \
		printf '%s\n' "makefiles: unknown module '$(MF_DISPATCH_MODULE)'; imported modules: $(or $(sort $(MF_MODULES)),(none))" >&2; \
		printf '%s\n' 'makefiles: usage: make <target> | make <module> <target>' >&2; \
		exit 2; \
	elif [ -z "$(filter $(MF_DISPATCH_TARGET),$(MF_MODULE_TARGETS_$(MF_DISPATCH_MODULE)))" ]; then \
		printf '%s\n' "makefiles: target '$(MF_DISPATCH_TARGET)' is not available in module '$(MF_DISPATCH_MODULE)'; available targets: $(or $(sort $(MF_MODULE_TARGETS_$(MF_DISPATCH_MODULE))),(none))" >&2; \
		exit 2; \
	else \
		if [ -n "$(MF_DISPATCH_SETUP)" ] && [ -n "$(filter $(MF_DISPATCH_MODULE):$(MF_DISPATCH_TARGET),$(MF_DISPATCH_SETUP_PAIRS))" ]; then \
			$(MAKE) --no-print-directory "$(MF_DISPATCH_SETUP)" || exit $$?; \
		fi; \
		$(MAKE) MF_SCOPED_MODULE="$(MF_DISPATCH_MODULE)" -f "$(MF_MODULE_ENTRY_$(MF_DISPATCH_MODULE))" "$(MF_DISPATCH_TARGET)"; \
	fi
endif
endif
endif