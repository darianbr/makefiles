#
# Filename: modules/vitest/prerequisites.mk
# Last edited: 2026-11-02 18:27:05
# Description: npm, project, and Vitest executable prerequisite checks.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/vitest/prerequisites.mk.)
endif

ifndef MF_VITEST_PREREQUISITES_INCLUDED
MF_VITEST_PREREQUISITES_INCLUDED := 1

.PHONY: vitest-prerequisites

vitest-prerequisites:
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(NPM)" >/dev/null 2>&1); then \
		echo "[vitest] npm executable not found: $(NPM)" >&2; \
		exit 1; \
	elif [ ! -f "$(MF_PROJECT_ROOT)package.json" ]; then \
		echo "[vitest] package.json not found in $(MF_PROJECT_ROOT)" >&2; \
		exit 1; \
	elif [ -f "$(VITEST_BIN)" ] || (cd "$(MF_PROJECT_ROOT)" && command -v vitest >/dev/null 2>&1); then \
		:; \
	else \
		echo "[vitest] Vitest executable not found; attempting npm install."; \
		if [ -f "$(MF_MODULES_ROOT)npm/Makefile" ]; then \
			$(MAKE) --no-print-directory npm install || exit $$?; \
		else \
			$(MAKE) --no-print-directory install || exit $$?; \
		fi; \
		if [ -f "$(VITEST_BIN)" ] || (cd "$(MF_PROJECT_ROOT)" && command -v vitest >/dev/null 2>&1); then \
			:; \
		else \
			echo "[vitest] Vitest executable is still missing: $(VITEST_BIN)" >&2; \
			exit 1; \
		fi; \
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

endif
