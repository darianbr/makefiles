#
# Filename: modules/vitest/targets.mk
# Last edited: 2026-11-04 20:19:22
# Description: Vitest module target recipes.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/vitest/targets.mk.)
endif

ifndef MF_VITEST_TARGETS_INCLUDED
MF_VITEST_TARGETS_INCLUDED := 1

.PHONY: help test coverage coverage-open clean install

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

install:: vitest-prerequisites
	@echo "[vitest] Vitest prerequisites are ready"

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

endif
