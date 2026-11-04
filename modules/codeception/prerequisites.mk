#
# Filename: modules/codeception/prerequisites.mk
# Last edited: 2026-11-04 20:19:22
# Description: Codeception executable, coverage, and setup prerequisite rules.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/codeception/prerequisites.mk.)
endif

ifndef MF_CODECEPTION_PREREQUISITES_INCLUDED
MF_CODECEPTION_PREREQUISITES_INCLUDED := 1

MF_CODECEPTION_PATH_DISCOVERY_SCRIPT := $(MF_MODULES_ROOT)codeception/discover-paths.sh
MF_CODECEPTION_COVERAGE_CACHE_PATH := $(MF_CACHE_ROOT)codeception-coverage-dir
MF_CODECEPTION_COVERAGE_INDEX_CACHE_PATH := $(MF_CACHE_ROOT)codeception-coverage-index
MF_CODECEPTION_CONFIG_DEP := $(wildcard $(MF_PROJECT_ROOT)codeception.yml)

.PHONY: codeception-prerequisites codeception-ready

$(MF_CODECEPTION_PATH_DISCOVERY_SCRIPT):
	@echo "[codeception] refreshing cached module files"
	@$(MAKE) --no-print-directory -B "$(MF_MODULES_ROOT)codeception/Makefile"
	@if [ ! -f "$@" ]; then \
		echo "[codeception] missing discovery script after refresh: $@" >&2; \
		exit 1; \
	fi

$(MF_CODECEPTION_COVERAGE_CACHE_PATH): $(MF_CODECEPTION_PATH_DISCOVERY_SCRIPT) $(MF_CODECEPTION_CONFIG_DEP)
	@mkdir -p "$(dir $@)"
	@resolved=''; \
	if [ -x "$(MF_CODECEPTION_PATH_DISCOVERY_SCRIPT)" ]; then \
		resolved=$$("$(MF_CODECEPTION_PATH_DISCOVERY_SCRIPT)" "$(MF_PROJECT_ROOT)" 2>/dev/null || true); \
	fi; \
	if [ -z "$$resolved" ]; then \
		resolved="$(MF_PROJECT_ROOT)_output/coverage"; \
	fi; \
	printf '%s\n' "$$resolved" > "$@"

codeception-prerequisites:
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(PHP)" >/dev/null 2>&1); then \
		echo "[codeception] PHP executable not found: $(PHP)" >&2; \
		echo "[codeception] Install PHP or invoke make with PHP=/path/to/php." >&2; \
		exit 1; \
	fi
	@if cd "$(MF_PROJECT_ROOT)" && { [ -f "$(CODECEPTION)" ] || command -v "$(CODECEPTION)" >/dev/null 2>&1; }; then \
		:; \
	else \
		echo "[codeception] Codeception executable not found; attempting Composer install."; \
		if [ -f "$(MF_MODULES_ROOT)composer/Makefile" ]; then \
			$(MAKE) --no-print-directory composer install || exit $$?; \
		else \
			$(MAKE) --no-print-directory install || exit $$?; \
		fi; \
		if cd "$(MF_PROJECT_ROOT)" && { [ -f "$(CODECEPTION)" ] || command -v "$(CODECEPTION)" >/dev/null 2>&1; }; then \
			:; \
		else \
			echo "[codeception] Codeception executable is still missing: $(CODECEPTION)" >&2; \
			echo "[codeception] Install dependencies manually or invoke make with CODECEPTION=/path/to/codecept." >&2; \
			exit 1; \
		fi; \
	fi

codeception-ready: codeception-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(CODECEPTION)" ]; then \
		"$(PHP)" "$(CODECEPTION)" build; \
	else \
		"$(CODECEPTION)" build; \
	fi

$(MF_CODECEPTION_COVERAGE_INDEX_CACHE_PATH): coverage $(MF_CODECEPTION_COVERAGE_CACHE_PATH)
	@mkdir -p "$(dir $@)"
	@coverage_dir=$$(cat "$(MF_CODECEPTION_COVERAGE_CACHE_PATH)"); \
	coverage_index="$$coverage_dir/index.html"; \
	if ! (cd "$(MF_PROJECT_ROOT)" && [ -f "$$coverage_index" ]); then \
		echo "[codeception] Coverage report was not generated: $$coverage_index" >&2; \
		exit 1; \
	fi; \
	printf '%s\n' "$$coverage_index" > "$@"

endif
