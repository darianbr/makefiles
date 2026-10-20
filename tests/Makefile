-include .makefiles/modules/codeception/Makefile
-include .makefiles/modules/composer/Makefile
-include .makefiles/modules/npm/Makefile
-include .makefiles/modules/phpunit/Makefile
-include .makefiles/modules/typescript/Makefile
-include .makefiles/modules/vitest/Makefile

# Pull the composer module (and the shared root Makefile) the first time it's needed.
.makefiles/modules/%/Makefile:
	@mkdir -p .makefiles/modules
	@cp -rp ../modules/. .makefiles/modules/