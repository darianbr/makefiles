#
# Filename: modules/typescript/targets.mk
# Last edited: 2026-10-20 22:40:56
# Description: TypeScript module target recipes.
#

.PHONY: echopath build test clean typescript-prerequisites typescript-dependencies

typescript-dependencies:
	@if [ -f "$(MF_MODULES_ROOT)npm/Makefile" ]; then \
		$(MAKE) --no-print-directory npm install || exit $$?; \
	fi

typescript-prerequisites: typescript-dependencies
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(NPM)" >/dev/null 2>&1); then \
		echo "[typescript] npm executable not found: $(NPM)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)package.json" ]; then \
		echo "[typescript] package.json not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)$(TSC_PROJECT)" ]; then \
		echo "[typescript] project file not found: $(MF_PROJECT_ROOT)$(TSC_PROJECT)" >&2; \
		exit 1; \
	elif [ -f "$(TSC)" ] || (cd "$(MF_PROJECT_ROOT)" && command -v tsc >/dev/null 2>&1); then \
		:; \
	else \
		echo "[typescript] TypeScript executable not found after dependency install: $(TSC)" >&2; \
		if [ -f "$(TSC)" ] || (cd "$(MF_PROJECT_ROOT)" && command -v tsc >/dev/null 2>&1); then \
			:; \
		else \
			echo "[typescript] TypeScript executable is still missing: $(TSC)" >&2; \
			exit 1; \
		fi; \
	fi

echopath::
	@echo "TypeScript module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo "NPM: $(NPM)"
	@echo "TSC: $(TSC)"
	@echo "TSC_PROJECT: $(TSC_PROJECT)"
	@echo "TSC_BUILD_OUT_DIR: $(TSC_BUILD_OUT_DIR)"
	@echo ""

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
