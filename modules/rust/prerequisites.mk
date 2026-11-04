#
# Filename: modules/rust/prerequisites.mk
# Last edited: 2026-11-02 18:25:58
# Description: Cargo executable and manifest prerequisite check.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/rust/prerequisites.mk.)
endif

ifndef MF_RUST_PREREQUISITES_INCLUDED
MF_RUST_PREREQUISITES_INCLUDED := 1

.PHONY: rust-prerequisites

rust-prerequisites:
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(CARGO)" >/dev/null 2>&1); then \
		echo "[rust] cargo executable not found: $(CARGO)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)Cargo.toml" ]; then \
		echo "[rust] Cargo.toml not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	fi

endif
