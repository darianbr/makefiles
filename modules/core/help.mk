#
# Filename: modules/core/help.mk
# Last edited: 2026-11-04 20:19:22
# Description: Top-level help for aggregate and module-scoped target usage.
#

ifeq ($(strip $(MF_SCOPED_MODULE)),)
.PHONY: help
help:
	@printf '%s\n' \
		'makefiles help' \
		'Usage:' \
		'  make help                  show this top-level help' \
		'  make <target>              run a target across imported modules' \
		'  make <module> <target>     run one module target' \
		'  make <module> help         show one module public targets' \
		'' \
		'Imported modules: $(or $(sort $(MF_MODULES)),(none))' \
		'Aggregate targets: $(sort clean $(filter-out help,$(foreach module,$(MF_MODULES),$(MF_MODULE_TARGETS_$(module)))))'
endif