.DEFAULT_GOAL := check

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: check check-manifest check-shell

check: check-manifest check-shell

check-manifest:
	@diff -u \
		<(LC_ALL=C sort modules/manifest.txt) \
		<(find modules -type f ! -path 'modules/manifest.txt' -print \
			| sed 's#^modules/##' \
			| LC_ALL=C sort)

check-shell:
	@bash -n fetch
	@find modules -type f -name '*.sh' -exec sh -n {} +
