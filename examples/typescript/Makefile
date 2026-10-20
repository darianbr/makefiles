-include .makefiles/modules/typescript/Makefile
-include .makefiles/modules/npm/Makefile

.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
