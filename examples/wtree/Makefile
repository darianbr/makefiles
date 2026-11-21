WTREE_PORT ?= 8000
export WTREE_PORT

-include .makefiles/modules/wtree/Makefile

.PHONY: start stop

# The dev server is project-owned and runs in the foreground.
start:
	$(MAKE) wtree up
	python3 -m http.server "$$WTREE_PORT" --bind 127.0.0.1

stop:
	$(MAKE) wtree down

.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
