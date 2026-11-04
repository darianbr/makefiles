#
# Filename: modules/phpunit/install-binary.mk
# Last edited: 2026-11-02 18:34:19
# Description: Compatibility include for PHPUnit binary-install targets.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/phpunit/install-binary.mk.)
endif

-include .makefiles/modules/phpunit/prerequisites.mk
-include .makefiles/modules/phpunit/targets.mk
