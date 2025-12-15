#
# Filename: modules/composer/install-binary.mk
# Last edited: 2025-12-15 09:41:09
# Description: Downloads and verifies composer.phar into the tools cache.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using install-binary.mk.)
endif

install-composer-binary:
	@mkdir -p $(MF_TOOLS_ROOT)
	@curl -sS https://getcomposer.org/installer -o $(MF_TOOLS_ROOT)composer-setup.php
	@curl -sS https://composer.github.io/installer.sig -o $(MF_TOOLS_ROOT)composer-setup.sig
	@EXPECTED_SIG=$$(cat $(MF_TOOLS_ROOT)composer-setup.sig); \
	ACTUAL_SIG=$$(php -r "echo hash_file('sha384', '$(MF_TOOLS_ROOT)composer-setup.php');"); \
	if [ "$$EXPECTED_SIG" != "$$ACTUAL_SIG" ]; then \
		echo "ERROR: Invalid installer signature"; \
		rm -f $(MF_TOOLS_ROOT)composer-setup.php $(MF_TOOLS_ROOT)composer-setup.sig; \
		exit 1; \
	fi
	@php $(MF_TOOLS_ROOT)composer-setup.php --install-dir=$(MF_TOOLS_ROOT) --filename=composer.phar
	@rm -f $(MF_TOOLS_ROOT)composer-setup.php $(MF_TOOLS_ROOT)composer-setup.sig