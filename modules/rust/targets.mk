#
# Filename: modules/rust/targets.mk
# Last edited: 2026-11-02 18:26:47
# Description: Rust module target recipes.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/rust/targets.mk.)
endif

ifndef MF_RUST_TARGETS_INCLUDED
MF_RUST_TARGETS_INCLUDED := 1

.PHONY: help echopath build test clippy fmt clean install

help::
	@printf '%s\n' 'rust targets: $(MF_MODULE_TARGETS_rust)'

echopath::
	@echo "Rust module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo "CARGO: $(CARGO)"
	@echo "CARGO_TARGET_DIR: $(CARGO_TARGET_DIR)"
	@echo ""

build:: rust-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && "$(CARGO)" build $(CARGO_BUILD_ARGS)

test:: rust-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && "$(CARGO)" test $(CARGO_TEST_ARGS)

clippy:: rust-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && "$(CARGO)" clippy $(CARGO_CLIPPY_ARGS)

fmt:: rust-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && "$(CARGO)" fmt $(CARGO_FMT_ARGS)

install:: rust-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && "$(CARGO)" fetch

clean::
	@project_root="$(MF_PROJECT_ROOT)"; \
	project_root=$${project_root%/}; \
	remove_script="$(MF_MODULES_ROOT)core/remove-with-guardrails.sh"; \
	if [ ! -f "$$remove_script" ] && [ -f "/tmp/mf-remove-with-guardrails.sh" ]; then \
		remove_script="/tmp/mf-remove-with-guardrails.sh"; \
	fi; \
	if [ ! -f "$$remove_script" ]; then \
		echo "[rust] missing guardrails helper script" >&2; \
		exit 1; \
	fi; \
	target_dir=""; \
	if (cd "$$project_root" && command -v "$(CARGO)" >/dev/null 2>&1) && [ -f "$$project_root/Cargo.toml" ]; then \
		target_dir=$$(cd "$$project_root" && "$(CARGO)" metadata --format-version 1 --no-deps 2>/dev/null | sed -n 's/.*"target_directory":"\([^"]*\)".*/\1/p' | head -n 1); \
	fi; \
	if [ -z "$$target_dir" ]; then \
		target_dir="$(CARGO_TARGET_DIR)"; \
	fi; \
	case "$$target_dir" in \
		/*) ;; \
		*) target_dir="$$project_root/$$target_dir" ;; \
	esac; \
	sh "$$remove_script" "$$project_root" rust dir "$$target_dir"

endif
