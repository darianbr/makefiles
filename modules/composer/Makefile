#
# Filename: modules/composer/Makefile
# Last edited: 2026-11-04 12:15:45
# Description: Composer module controller that registers targets and includes recipes.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/composer/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/composer/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),install clean install-composer-binary help))

PHP ?= php
COMPOSER := $(MF_TOOLS_ROOT)composer.phar
MF_COMPOSER_EMPTY :=
MF_COMPOSER_SPACE := $(MF_COMPOSER_EMPTY) $(MF_COMPOSER_EMPTY)
MF_COMPOSER_TARGET := $(subst $(MF_COMPOSER_SPACE),\$(MF_COMPOSER_SPACE),$(COMPOSER))

-include .makefiles/modules/composer/prerequisites.mk
-include .makefiles/modules/composer/targets.mk
