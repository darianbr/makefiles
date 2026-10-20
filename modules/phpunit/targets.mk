#
# Filename: modules/phpunit/targets.mk
# Last edited: 2026-10-20 18:10:00
# Description: PHPUnit module target recipes.
#

MF_PHPUNIT_PATH_DISCOVERY_SCRIPT := $(MF_MODULES_ROOT)phpunit/discover-paths.sh
MF_PHPUNIT_COVERAGE_CACHE_PATH := $(MF_MAKEFILES_ROOT).cache/phpunit-coverage-dir
MF_PHPUNIT_CONFIG_FILE := $(if $(wildcard $(MF_PROJECT_ROOT)phpunit.xml),$(MF_PROJECT_ROOT)phpunit.xml,(default fallback: coverage))
MF_PHPUNIT_CONFIG_DEP := $(wildcard $(MF_PROJECT_ROOT)phpunit.xml)

.PHONY: echopath test coverage coverage-open clean phpunit-prerequisites install-phpunit-binary

$(MF_PHPUNIT_PATH_DISCOVERY_SCRIPT):
	@echo "[phpunit] refreshing cached module files"
	@$(MAKE) --no-print-directory -B "$(MF_MODULES_ROOT)phpunit/Makefile"
	@if [ ! -f "$@" ]; then \
		echo "[phpunit] missing discovery script after refresh: $@" >&2; \
		exit 1; \
	fi

$(MF_PHPUNIT_COVERAGE_CACHE_PATH): $(MF_PHPUNIT_PATH_DISCOVERY_SCRIPT) $(MF_PHPUNIT_CONFIG_DEP)
	@mkdir -p "$(dir $@)"
	@resolved=''; \
	if [ -x "$(MF_PHPUNIT_PATH_DISCOVERY_SCRIPT)" ]; then \
		resolved=$$("$(MF_PHPUNIT_PATH_DISCOVERY_SCRIPT)" "$(MF_PROJECT_ROOT)" 2>/dev/null || true); \
	fi; \
	if [ -z "$$resolved" ]; then \
		resolved="$(MF_PROJECT_ROOT)coverage"; \
	fi; \
	printf '%s\n' "$$resolved" > "$@"

echopath:: $(MF_PHPUNIT_COVERAGE_CACHE_PATH)
	@echo "PHPUnit module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo "PHPUNIT: $(PHPUNIT)"
	@echo "PHPUNIT_CONFIG: $(MF_PHPUNIT_CONFIG_FILE)"
	@coverage_dir=$$(cat "$(MF_PHPUNIT_COVERAGE_CACHE_PATH)"); echo "PHPUNIT_COVERAGE_DIR: $$coverage_dir"
	@echo ""

phpunit-prerequisites:
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(PHP)" >/dev/null 2>&1); then \
		echo "[phpunit] PHP executable not found: $(PHP)" >&2; \
		echo "[phpunit] Install PHP or invoke make with PHP=/path/to/php." >&2; \
		exit 1; \
	fi
	@if cd "$(MF_PROJECT_ROOT)" && { [ -f "$(PHPUNIT)" ] || command -v "$(PHPUNIT)" >/dev/null 2>&1; }; then \
		:; \
	else \
		echo "[phpunit] PHPUnit executable not found; attempting Composer install."; \
		if [ -f "$(MF_MODULES_ROOT)composer/Makefile" ]; then \
			$(MAKE) --no-print-directory composer install || exit $$?; \
		else \
			$(MAKE) --no-print-directory install || exit $$?; \
		fi; \
		if cd "$(MF_PROJECT_ROOT)" && { [ -f "$(PHPUNIT)" ] || command -v "$(PHPUNIT)" >/dev/null 2>&1; }; then \
			:; \
		else \
			echo "[phpunit] PHPUnit executable is still missing: $(PHPUNIT)" >&2; \
			echo "[phpunit] Install dependencies manually or invoke make with PHPUNIT=/path/to/phpunit." >&2; \
			exit 1; \
		fi; \
	fi

test:: phpunit-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(PHPUNIT)" ]; then \
		"$(PHP)" "$(PHPUNIT)" $(PHPUNIT_ARGS); \
	else \
		"$(PHPUNIT)" $(PHPUNIT_ARGS); \
	fi

coverage:: phpunit-prerequisites $(MF_PHPUNIT_COVERAGE_CACHE_PATH)
	@coverage_dir=$$(cat "$(MF_PHPUNIT_COVERAGE_CACHE_PATH)"); \
	cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(PHPUNIT)" ]; then \
		"$(PHP)" "$(PHPUNIT)" --coverage-html "$$coverage_dir" $(PHPUNIT_ARGS); \
	else \
		"$(PHPUNIT)" --coverage-html "$$coverage_dir" $(PHPUNIT_ARGS); \
	fi

coverage-open:: coverage
	@coverage_dir=$$(cat "$(MF_PHPUNIT_COVERAGE_CACHE_PATH)"); \
	if ! (cd "$(MF_PROJECT_ROOT)" && [ -f "$$coverage_dir/index.html" ]); then \
		echo "[phpunit] Coverage report was not generated: $$coverage_dir/index.html" >&2; \
		exit 1; \
	fi
	@if [ -n "$(BROWSER)" ]; then \
		if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(BROWSER)" >/dev/null 2>&1); then \
			echo "[phpunit] Browser opener not found: $(BROWSER)" >&2; \
			exit 1; \
		fi; \
		cd "$(MF_PROJECT_ROOT)" && "$(BROWSER)" "$$coverage_dir/index.html"; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		cd "$(MF_PROJECT_ROOT)" && xdg-open "$$coverage_dir/index.html"; \
	elif command -v open >/dev/null 2>&1; then \
		cd "$(MF_PROJECT_ROOT)" && open "$$coverage_dir/index.html"; \
	else \
		echo "[phpunit] No browser opener found; open $$coverage_dir/index.html manually." >&2; \
		exit 1; \
	fi

# Remove the generated HTML coverage report without touching other project data.
clean:: $(MF_PHPUNIT_COVERAGE_CACHE_PATH)
	@coverage_dir=$$(cat "$(MF_PHPUNIT_COVERAGE_CACHE_PATH)"); \
	if [ -d "$$coverage_dir" ]; then \
		echo "[phpunit] removing coverage directory $$coverage_dir"; \
		rm -rf "$$coverage_dir"; \
	else \
		echo "[phpunit] coverage directory not found; skipping"; \
	fi