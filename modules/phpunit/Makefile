#
# Filename: modules/phpunit/Makefile
# Last edited: 2026-10-20 18:10:00
# Description: PHPUnit module controller that registers targets and includes recipes.
#

-include .makefiles/modules/Makefile

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/phpunit/Makefile.)
endif

MF_CURRENT_MODULE_ENTRY := $(lastword $(filter %/modules/phpunit/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),echopath test coverage coverage-open install-phpunit-binary clean))

# PHPUnit is normally installed by the consuming project's Composer manifest.
# Override PHPUNIT when a project keeps the executable somewhere else.
PHP ?= php
PHPUNIT ?= $(MF_PROJECT_ROOT)vendor/bin/phpunit
PHPUNIT_ARGS ?=

# The standalone PHAR is opt-in: PHPUNIT continues to default to the
# consuming project's Composer-installed executable above.
PHPUNIT_PHAR ?= $(MF_TOOLS_ROOT)phpunit.phar
MF_PHPUNIT_EMPTY :=
MF_PHPUNIT_SPACE := $(MF_PHPUNIT_EMPTY) $(MF_PHPUNIT_EMPTY)
MF_PHPUNIT_PHAR_TARGET := $(subst $(MF_PHPUNIT_SPACE),\$(MF_PHPUNIT_SPACE),$(PHPUNIT_PHAR))
PHPUNIT_VERSION ?= latest
PHPUNIT_URL ?= $(if $(filter latest,$(PHPUNIT_VERSION)),https://phar.phpunit.de/phpunit.phar,https://phar.phpunit.de/phpunit-$(PHPUNIT_VERSION).phar)

-include .makefiles/modules/phpunit/install-binary.mk

-include .makefiles/modules/phpunit/targets.mk

