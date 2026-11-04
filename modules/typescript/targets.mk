#
# Filename: modules/typescript/targets.mk
# Last edited: 2026-11-04 20:19:22
# Description: TypeScript module target recipes.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/typescript/targets.mk.)
endif

ifndef MF_TYPESCRIPT_TARGETS_INCLUDED
MF_TYPESCRIPT_TARGETS_INCLUDED := 1

.PHONY: help build test clean install

build:: typescript-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(TSC)" ]; then \
		"$(TSC)" $(TSC_BUILD_ARGS); \
	else \
		"$(NPM)" exec -- tsc $(TSC_BUILD_ARGS); \
	fi

test:: typescript-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(TSC)" ]; then \
		"$(TSC)" $(TSC_TEST_ARGS); \
	else \
		"$(NPM)" exec -- tsc $(TSC_TEST_ARGS); \
	fi

install:: typescript-prerequisites
	@echo "[typescript] TypeScript prerequisites are ready"

clean::
	@build_out_dir="$(TSC_BUILD_OUT_DIR)"; \
	project_root="$(MF_PROJECT_ROOT)"; \
	project_root=$${project_root%/}; \
	remove_script="$(MF_MODULES_ROOT)core/remove-with-guardrails.sh"; \
	if [ ! -f "$$remove_script" ] && [ -f "/tmp/mf-remove-with-guardrails.sh" ]; then \
		remove_script="/tmp/mf-remove-with-guardrails.sh"; \
	fi; \
	if [ ! -f "$$remove_script" ]; then \
		echo "[typescript] missing guardrails helper script" >&2; \
		exit 1; \
	fi; \
	case "$$build_out_dir" in \
		/*) ;; \
		*) build_out_dir="$(MF_PROJECT_ROOT)$$build_out_dir" ;; \
	esac; \
	sh "$$remove_script" "$$project_root" typescript dir "$$build_out_dir"; \
	sh "$$remove_script" "$$project_root" typescript file "$(MF_PROJECT_ROOT).tsbuildinfo"

endif
