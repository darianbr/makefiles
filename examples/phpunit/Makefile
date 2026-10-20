-include .makefiles/modules/phpunit/Makefile
-include .makefiles/modules/composer/Makefile

.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
