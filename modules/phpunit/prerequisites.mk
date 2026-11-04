#
# Filename: modules/phpunit/prerequisites.mk
# Last edited: 2026-11-04 20:19:22
# Description: PHPUnit executable, coverage, and setup prerequisite rules.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/phpunit/prerequisites.mk.)
endif

ifndef MF_PHPUNIT_PREREQUISITES_INCLUDED
MF_PHPUNIT_PREREQUISITES_INCLUDED := 1

MF_PHPUNIT_PATH_DISCOVERY_SCRIPT := $(MF_MODULES_ROOT)phpunit/discover-paths.sh
MF_PHPUNIT_COVERAGE_CACHE_PATH := $(MF_CACHE_ROOT)phpunit-coverage-dir
MF_PHPUNIT_COVERAGE_INDEX_CACHE_PATH := $(MF_CACHE_ROOT)phpunit-coverage-index
MF_PHPUNIT_CONFIG_DEP := $(wildcard $(MF_PROJECT_ROOT)phpunit.xml)

.PHONY: phpunit-prerequisites

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

$(MF_PHPUNIT_COVERAGE_INDEX_CACHE_PATH): coverage $(MF_PHPUNIT_COVERAGE_CACHE_PATH)
	@mkdir -p "$(dir $@)"
	@coverage_dir=$$(cat "$(MF_PHPUNIT_COVERAGE_CACHE_PATH)"); \
	coverage_index="$$coverage_dir/index.html"; \
	if ! (cd "$(MF_PROJECT_ROOT)" && [ -f "$$coverage_index" ]); then \
		echo "[phpunit] Coverage report was not generated: $$coverage_index" >&2; \
		exit 1; \
	fi; \
	printf '%s\n' "$$coverage_index" > "$@"

endif
