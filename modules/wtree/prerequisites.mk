#
# Filename: modules/wtree/prerequisites.mk
# Last edited: 2026-11-20
# Description: Lazily install a checksum-verified wtree release binary.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/wtree/prerequisites.mk.)
endif

ifndef MF_WTREE_PREREQUISITES_INCLUDED
MF_WTREE_PREREQUISITES_INCLUDED := 1

WTREE_VERSION ?= 0.1.0
WTREE_BIN ?= $(MF_TOOLS_ROOT)wtree-$(WTREE_VERSION)
WTREE_RELEASE_URL ?= https://github.com/darianbr/worktree/releases/download/v$(WTREE_VERSION)
WTREE_PORT ?=
WTREE_SLUG ?=
export WTREE_VERSION WTREE_BIN WTREE_RELEASE_URL WTREE_PORT WTREE_SLUG
export WTREE_CONTAINER_ENGINE WTREE_CERT_FILE WTREE_KEY_FILE

.PHONY: mf-wtree-ensure
mf-wtree-ensure:
	@set -eu; \
	case "$$WTREE_VERSION" in ''|[!0-9]*|*[!a-zA-Z0-9.+-]*) echo '[wtree] invalid WTREE_VERSION (use the release version without v)' >&2; exit 1 ;; esac; \
	dest=$$WTREE_BIN; \
	if [ -z "$$dest" ]; then echo '[wtree] WTREE_BIN must be a non-symlink file path' >&2; exit 1; fi; \
	case "$$dest" in /*) ;; *) dest="./$$dest" ;; esac; \
	if [ -d "$$dest" ] || [ -L "$$dest" ]; then \
		echo '[wtree] WTREE_BIN must be a non-symlink file path' >&2; exit 1; \
	fi; \
	if [ -f "$$dest" ] && [ -x "$$dest" ]; then exit 0; fi; \
	for tool in curl tar uname awk mktemp mkdir chmod mv rm; do \
		if ! command -v "$$tool" >/dev/null 2>&1; then \
			echo "[wtree] required tool not found: $$tool" >&2; exit 1; \
		fi; \
	done; \
	if command -v sha256sum >/dev/null 2>&1; then checksum=sha256sum; \
	elif command -v shasum >/dev/null 2>&1; then checksum=shasum; \
	else echo '[wtree] SHA-256 tool required: install sha256sum or shasum' >&2; exit 1; fi; \
	case "$$(uname -s)" in Linux) os=linux ;; Darwin) os=darwin ;; \
		*) echo '[wtree] unsupported operating system (supported: Linux and macOS)' >&2; exit 1 ;; esac; \
	case "$$(uname -m)" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; \
		*) echo '[wtree] unsupported architecture (supported: amd64 and arm64)' >&2; exit 1 ;; esac; \
	case "$$WTREE_RELEASE_URL" in https://*) ;; *) echo '[wtree] release URL must use HTTPS' >&2; exit 1 ;; esac; \
	archive="wtree_$${WTREE_VERSION}_$${os}_$${arch}.tar.gz"; \
	dir=$${dest%/*}; if [ "$$dir" = "$$dest" ]; then dir=.; fi; \
	mkdir -p "$$dir"; \
	tmp=$$(mktemp -d "$$dir/.wtree.XXXXXXXX"); \
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM; \
	curl -fsSL --proto '=https' --proto-redir '=https' "$$WTREE_RELEASE_URL/$$archive" -o "$$tmp/archive.tar.gz"; \
	curl -fsSL --proto '=https' --proto-redir '=https' "$$WTREE_RELEASE_URL/SHA256SUMS" -o "$$tmp/SHA256SUMS"; \
	expected=$$(awk -v name="$$archive" '$$2 == name || $$2 == "*" name { if (length($$1) == 64 && $$1 ~ /^[[:xdigit:]]+$$/) { print tolower($$1); count++ } else { bad=1 } } END { if (count != 1 || bad) exit 1 }' "$$tmp/SHA256SUMS") || \
		{ echo "[wtree] missing, invalid, or duplicate checksum for $$archive" >&2; exit 1; }; \
	if [ "$$checksum" = sha256sum ]; then actual=$$(sha256sum < "$$tmp/archive.tar.gz"); \
	else actual=$$(shasum -a 256 < "$$tmp/archive.tar.gz"); fi; \
	actual=$${actual%% *}; \
	if [ "$$actual" != "$$expected" ]; then echo "[wtree] checksum mismatch for $$archive" >&2; exit 1; fi; \
	entries=$$(tar -tvzf "$$tmp/archive.tar.gz" wtree) || \
		{ echo '[wtree] archive does not contain a regular wtree binary' >&2; exit 1; }; \
	if ! printf '%s\n' "$$entries" | awk 'NR == 1 && substr($$0, 1, 1) == "-" { regular=1 } END { exit !(NR == 1 && regular) }'; then \
		echo '[wtree] archive does not contain a regular wtree binary' >&2; exit 1; \
	fi; \
	(cd "$$tmp" && tar -xzf archive.tar.gz wtree); \
	if [ ! -f "$$tmp/wtree" ] || [ -L "$$tmp/wtree" ]; then echo '[wtree] archive does not contain a regular wtree binary' >&2; exit 1; fi; \
	chmod 755 "$$tmp/wtree"; \
	mv -f "$$tmp/wtree" "$$dest"; \
	echo "[wtree] installed $$dest"

endif