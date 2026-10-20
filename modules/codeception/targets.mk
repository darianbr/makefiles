#
# Filename: modules/codeception/targets.mk
# Last edited: 2026-10-20 18:10:00
# Description: Codeception module target recipes.
#

MF_CODECEPTION_PATH_DISCOVERY_SCRIPT := $(MF_MODULES_ROOT)codeception/discover-paths.sh
MF_CODECEPTION_COVERAGE_DIR_CACHE_FILE := $(MF_MAKEFILES_ROOT).cache/codeception-coverage-dir
MF_CODECEPTION_CONFIG_FILE := $(if $(wildcard $(MF_PROJECT_ROOT)codeception.yml),$(MF_PROJECT_ROOT)codeception.yml,(default fallback: _output/coverage))
MF_CODECEPTION_CONFIG_DEP := $(wildcard $(MF_PROJECT_ROOT)codeception.yml)

.PHONY: echopath test coverage coverage-open clean codeception-prerequisites codeception-ready

$(MF_CODECEPTION_PATH_DISCOVERY_SCRIPT):
	@echo "[codeception] refreshing cached module files"
	@$(MAKE) --no-print-directory -B "$(MF_MODULES_ROOT)codeception/Makefile"
	@if [ ! -f "$@" ]; then \
		echo "[codeception] missing discovery script after refresh: $@" >&2; \
		exit 1; \
	fi

$(MF_CODECEPTION_COVERAGE_DIR_CACHE_FILE): $(MF_CODECEPTION_PATH_DISCOVERY_SCRIPT) $(MF_CODECEPTION_CONFIG_DEP)
	@mkdir -p "$(dir $@)"
	@resolved=''; \
	if [ -x "$(MF_CODECEPTION_PATH_DISCOVERY_SCRIPT)" ]; then \
		resolved=$$("$(MF_CODECEPTION_PATH_DISCOVERY_SCRIPT)" "$(MF_PROJECT_ROOT)" 2>/dev/null || true); \
	fi; \
	if [ -z "$$resolved" ]; then \
		resolved="$(MF_PROJECT_ROOT)_output/coverage"; \
	fi; \
	printf '%s\n' "$$resolved" > "$@"

echopath:: $(MF_CODECEPTION_COVERAGE_DIR_CACHE_FILE)
	@echo "Codeception module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo "CODECEPTION: $(CODECEPTION)"
	@echo "CODECEPTION_CONFIG: $(MF_CODECEPTION_CONFIG_FILE)"
	@coverage_dir=$$(cat "$(MF_CODECEPTION_COVERAGE_DIR_CACHE_FILE)"); echo "CODECEPTION_COVERAGE_DIR: $$coverage_dir"
	@echo ""

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

# Ensure generated actor classes are up to date before running tests.
codeception-ready: codeception-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(CODECEPTION)" ]; then \
		"$(PHP)" "$(CODECEPTION)" build; \
	else \
		"$(CODECEPTION)" build; \
	fi

test:: codeception-ready
	@cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(CODECEPTION)" ]; then \
		"$(PHP)" "$(CODECEPTION)" run $(CODECEPTION_ARGS); \
	else \
		"$(CODECEPTION)" run $(CODECEPTION_ARGS); \
	fi

coverage:: codeception-ready $(MF_CODECEPTION_COVERAGE_DIR_CACHE_FILE)
	@coverage_dir=$$(cat "$(MF_CODECEPTION_COVERAGE_DIR_CACHE_FILE)"); \
	cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(CODECEPTION)" ]; then \
		"$(PHP)" "$(CODECEPTION)" run --coverage --coverage-html "$$coverage_dir" $(CODECEPTION_ARGS); \
	else \
		"$(CODECEPTION)" run --coverage --coverage-html "$$coverage_dir" $(CODECEPTION_ARGS); \
	fi

coverage-open:: coverage
	@coverage_dir=$$(cat "$(MF_CODECEPTION_COVERAGE_DIR_CACHE_FILE)"); \
	if ! (cd "$(MF_PROJECT_ROOT)" && [ -f "$$coverage_dir/index.html" ]); then \
		echo "[codeception] Coverage report was not generated: $$coverage_dir/index.html" >&2; \
		exit 1; \
	fi
	@if [ -n "$(BROWSER)" ]; then \
		if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(BROWSER)" >/dev/null 2>&1); then \
			echo "[codeception] Browser opener not found: $(BROWSER)" >&2; \
			exit 1; \
		fi; \
		cd "$(MF_PROJECT_ROOT)" && "$(BROWSER)" "$$coverage_dir/index.html"; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		cd "$(MF_PROJECT_ROOT)" && xdg-open "$$coverage_dir/index.html"; \
	elif command -v open >/dev/null 2>&1; then \
		cd "$(MF_PROJECT_ROOT)" && open "$$coverage_dir/index.html"; \
	else \
		echo "[codeception] No browser opener found; open $$coverage_dir/index.html manually." >&2; \
		exit 1; \
	fi

# Remove the generated HTML coverage report without touching other test output.
clean:: $(MF_CODECEPTION_COVERAGE_DIR_CACHE_FILE)
	@coverage_dir=$$(cat "$(MF_CODECEPTION_COVERAGE_DIR_CACHE_FILE)"); \
	if [ -d "$$coverage_dir" ]; then \
		echo "[codeception] removing coverage directory $$coverage_dir"; \
		rm -rf "$$coverage_dir"; \
	else \
		echo "[codeception] coverage directory not found; skipping"; \
	fi