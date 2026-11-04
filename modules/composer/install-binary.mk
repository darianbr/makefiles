#
# Filename: modules/composer/install-binary.mk
# Last edited: 2026-11-02 18:34:19
# Description: Compatibility include for Composer binary-install targets.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/composer/install-binary.mk.)
endif

-include .makefiles/modules/composer/prerequisites.mk
-include .makefiles/modules/composer/targets.mk
