#
# Filename: modules/composer/Makefile
# Last edited: 2026-10-20 18:10:00
# Description: Composer module controller that registers targets and includes recipes.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/composer/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/composer/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),echopath install clean install-composer-binary))

PHP ?= php
COMPOSER := $(MF_TOOLS_ROOT)composer.phar
MF_COMPOSER_EMPTY :=
MF_COMPOSER_SPACE := $(MF_COMPOSER_EMPTY) $(MF_COMPOSER_EMPTY)
MF_COMPOSER_TARGET := $(subst $(MF_COMPOSER_SPACE),\$(MF_COMPOSER_SPACE),$(COMPOSER))

-include .makefiles/modules/composer/install-binary.mk
-include .makefiles/modules/composer/targets.mk
