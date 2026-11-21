.DEFAULT_GOAL := check

# Each recipe line is a single command, so Make's per-line exit-status check is
# sufficient; no .SHELLFLAGS (added in GNU Make 4.0) to stay compatible with the
# macOS Homebrew GNU Make 3.81 that the rest of this repository targets.
SHELL := /bin/bash

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
