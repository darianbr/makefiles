#
# Filename: modules/phpunit/install-binary.mk
# Last edited: 2026-10-20 12:23:52
# Description: Downloads the optional standalone PHPUnit PHAR into the tools cache.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/phpunit/install-binary.mk.)
endif

# This target is deliberately separate from the Composer-installed PHPUNIT
# executable used by test and coverage.  Call it explicitly when a project
# wants a cached standalone PHAR.
install-phpunit-binary:
	@set -eu; \
	mkdir -p "$$(dirname "$(PHPUNIT_PHAR)")"; \
	if [ -f "$(PHPUNIT_PHAR)" ]; then \
		echo "[phpunit] PHPUnit binary already present: $(PHPUNIT_PHAR)"; \
	else \
		tmp="$(PHPUNIT_PHAR).tmp"; \
		trap 'rm -f "$$tmp"' EXIT; \
		curl -fsSL "$(PHPUNIT_URL)" -o "$$tmp"; \
		chmod +x "$$tmp"; \
		mv "$$tmp" "$(PHPUNIT_PHAR)"; \
		echo "[phpunit] PHPUnit binary installed: $(PHPUNIT_PHAR)"; \
	fi

$(MF_PHPUNIT_PHAR_TARGET):
	@$(MAKE) install-phpunit-binary
