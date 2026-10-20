#
# Filename: modules/vitest/targets.mk
# Last edited: 2026-10-20 22:40:56
# Description: Vitest module target recipes.
#

.PHONY: echopath test coverage coverage-open clean vitest-prerequisites vitest-dependencies

vitest-dependencies:
	@if [ -f "$(MF_MODULES_ROOT)npm/Makefile" ]; then \
		$(MAKE) --no-print-directory npm install || exit $$?; \
	fi

vitest-prerequisites: vitest-dependencies
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(NPM)" >/dev/null 2>&1); then \
		echo "[vitest] npm executable not found: $(NPM)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)package.json" ]; then \
		echo "[vitest] package.json not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	elif [ -f "$(VITEST_BIN)" ] || (cd "$(MF_PROJECT_ROOT)" && command -v vitest >/dev/null 2>&1); then \
		:; \
	else \
		echo "[vitest] Vitest executable not found after dependency install: $(VITEST_BIN)" >&2; \
		if [ -f "$(VITEST_BIN)" ] || (cd "$(MF_PROJECT_ROOT)" && command -v vitest >/dev/null 2>&1); then \
			:; \
		else \
			echo "[vitest] Vitest executable is still missing: $(VITEST_BIN)" >&2; \
			exit 1; \
		fi; \
	fi

echopath::
	@echo "Vitest module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo "NPM: $(NPM)"
	@echo "VITEST_BIN: $(VITEST_BIN)"
	@echo "VITEST_COVERAGE_DIR: $(VITEST_COVERAGE_DIR)"
	@echo ""

test:: vitest-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(VITEST_BIN)" ]; then \
		"$(VITEST_BIN)" run $(VITEST_ARGS); \
	else \
		"$(NPM)" exec -- vitest run $(VITEST_ARGS); \
	fi

coverage:: vitest-prerequisites
	@coverage_dir="$(VITEST_COVERAGE_DIR)"; \
	case "$$coverage_dir" in \
		/*) ;; \
		*) coverage_dir="$(MF_PROJECT_ROOT)$$coverage_dir" ;; \
	esac; \
	cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(VITEST_BIN)" ]; then \
		"$(VITEST_BIN)" run --coverage --coverage.reporter=html --coverage.reportsDirectory "$$coverage_dir" $(VITEST_ARGS); \
	else \
		"$(NPM)" exec -- vitest run --coverage --coverage.reporter=html --coverage.reportsDirectory "$$coverage_dir" $(VITEST_ARGS); \
	fi

$(MF_VITEST_COVERAGE_INDEX_CACHE_PATH): coverage
	@mkdir -p "$(dir $@)"
	@coverage_dir="$(VITEST_COVERAGE_DIR)"; \
	case "$$coverage_dir" in \
		/*) ;; \
		*) coverage_dir="$(MF_PROJECT_ROOT)$$coverage_dir" ;; \
	esac; \
	coverage_index="$$coverage_dir/index.html"; \
	if ! (cd "$(MF_PROJECT_ROOT)" && [ -f "$$coverage_index" ]); then \
		echo "[vitest] Coverage report was not generated: $$coverage_index" >&2; \
		exit 1; \
	fi; \
	printf '%s\n' "$$coverage_index" > "$@"

coverage-open:: $(MF_VITEST_COVERAGE_INDEX_CACHE_PATH)
	@if [ -n "$(BROWSER)" ]; then \
		if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(BROWSER)" >/dev/null 2>&1); then \
			echo "[vitest] Browser opener not found: $(BROWSER)" >&2; \
			exit 1; \
		fi; \
		coverage_index=$$(cat "$(MF_VITEST_COVERAGE_INDEX_CACHE_PATH)"); \
		cd "$(MF_PROJECT_ROOT)" && "$(BROWSER)" "$$coverage_index"; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		coverage_index=$$(cat "$(MF_VITEST_COVERAGE_INDEX_CACHE_PATH)"); \
		cd "$(MF_PROJECT_ROOT)" && xdg-open "$$coverage_index"; \
	elif command -v open >/dev/null 2>&1; then \
		coverage_index=$$(cat "$(MF_VITEST_COVERAGE_INDEX_CACHE_PATH)"); \
		cd "$(MF_PROJECT_ROOT)" && open "$$coverage_index"; \
	else \
		coverage_index=$$(cat "$(MF_VITEST_COVERAGE_INDEX_CACHE_PATH)"); \
		echo "[vitest] No browser opener found; open $$coverage_index manually." >&2; \
		exit 1; \
	fi

clean::
	@coverage_dir="$(VITEST_COVERAGE_DIR)"; \
	project_root="$(MF_PROJECT_ROOT)"; \
	project_root=$${project_root%/}; \
	remove_script="$(MF_MODULES_ROOT)core/remove-with-guardrails.sh"; \
	if [ ! -f "$$remove_script" ] && [ -f "/tmp/mf-remove-with-guardrails.sh" ]; then \
		remove_script="/tmp/mf-remove-with-guardrails.sh"; \
	fi; \
	if [ ! -f "$$remove_script" ]; then \
		echo "[vitest] missing guardrails helper script" >&2; \
		exit 1; \
	fi; \
	case "$$coverage_dir" in \
		/*) ;; \
		*) coverage_dir="$(MF_PROJECT_ROOT)$$coverage_dir" ;; \
	esac; \
	sh "$$remove_script" "$$project_root" vitest dir "$$coverage_dir"
