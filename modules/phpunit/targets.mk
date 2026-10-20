#
# Filename: modules/phpunit/targets.mk
# Last edited: 2026-10-20 18:10:00
# Description: PHPUnit module target recipes.
#

MF_PHPUNIT_PATH_DISCOVERY_SCRIPT := $(MF_MODULES_ROOT)phpunit/discover-paths.sh
MF_PHPUNIT_COVERAGE_CACHE_PATH := $(MF_CACHE_ROOT)phpunit-coverage-dir
MF_PHPUNIT_COVERAGE_INDEX_CACHE_PATH := $(MF_CACHE_ROOT)phpunit-coverage-index
MF_PHPUNIT_CONFIG_FILE := $(if $(wildcard $(MF_PROJECT_ROOT)phpunit.xml),$(MF_PROJECT_ROOT)phpunit.xml,(default fallback: coverage))
MF_PHPUNIT_CONFIG_DEP := $(wildcard $(MF_PROJECT_ROOT)phpunit.xml)

.PHONY: echopath test coverage coverage-open clean phpunit-prerequisites install-phpunit-binary phpunit-dependencies

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

phpunit-dependencies:
	@if [ -f "$(MF_MODULES_ROOT)composer/Makefile" ]; then \
		$(MAKE) --no-print-directory composer install || exit $$?; \
	fi

phpunit-prerequisites: phpunit-dependencies
	@if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(PHP)" >/dev/null 2>&1); then \
		echo "[phpunit] PHP executable not found: $(PHP)" >&2; \
		echo "[phpunit] Install PHP or invoke make with PHP=/path/to/php." >&2; \
		exit 1; \
	fi
	@if cd "$(MF_PROJECT_ROOT)" && { [ -f "$(PHPUNIT)" ] || command -v "$(PHPUNIT)" >/dev/null 2>&1; }; then \
		:; \
	else \
		echo "[phpunit] PHPUnit executable not found after dependency install: $(PHPUNIT)" >&2; \
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
	if ! (cd "$(MF_PROJECT_ROOT)" && "$(PHP)" -m | grep -qiE '^(xdebug|pcov)$$'); then \
		echo "[phpunit] No coverage driver detected. Install and enable xdebug or pcov for line coverage." >&2; \
		echo "[phpunit] Hint: xdebug users may also need XDEBUG_MODE=coverage." >&2; \
		if [ -n "$(MF_SCOPED_MODULE)" ]; then \
			exit 1; \
		fi; \
		echo "[phpunit] skipping coverage in aggregate mode"; \
		exit 0; \
	fi; \
	cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(PHPUNIT)" ]; then \
		if "$(PHP)" -m | grep -qi '^xdebug$$'; then \
			XDEBUG_MODE=coverage "$(PHP)" "$(PHPUNIT)" --coverage-html "$$coverage_dir" $(PHPUNIT_ARGS); \
		else \
			"$(PHP)" "$(PHPUNIT)" --coverage-html "$$coverage_dir" $(PHPUNIT_ARGS); \
		fi; \
	else \
		if "$(PHP)" -m | grep -qi '^xdebug$$'; then \
			XDEBUG_MODE=coverage "$(PHPUNIT)" --coverage-html "$$coverage_dir" $(PHPUNIT_ARGS); \
		else \
			"$(PHPUNIT)" --coverage-html "$$coverage_dir" $(PHPUNIT_ARGS); \
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

coverage-open:: $(MF_PHPUNIT_COVERAGE_INDEX_CACHE_PATH)
	@if [ -n "$(BROWSER)" ]; then \
		if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(BROWSER)" >/dev/null 2>&1); then \
			echo "[phpunit] Browser opener not found: $(BROWSER)" >&2; \
			exit 1; \
		fi; \
		coverage_index=$$(cat "$(MF_PHPUNIT_COVERAGE_INDEX_CACHE_PATH)"); \
		cd "$(MF_PROJECT_ROOT)" && "$(BROWSER)" "$$coverage_index"; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		coverage_index=$$(cat "$(MF_PHPUNIT_COVERAGE_INDEX_CACHE_PATH)"); \
		cd "$(MF_PROJECT_ROOT)" && xdg-open "$$coverage_index"; \
	elif command -v open >/dev/null 2>&1; then \
		coverage_index=$$(cat "$(MF_PHPUNIT_COVERAGE_INDEX_CACHE_PATH)"); \
		cd "$(MF_PROJECT_ROOT)" && open "$$coverage_index"; \
	else \
		coverage_index=$$(cat "$(MF_PHPUNIT_COVERAGE_INDEX_CACHE_PATH)"); \
		echo "[phpunit] No browser opener found; open $$coverage_index manually." >&2; \
		exit 1; \
	fi

# Remove suite-generated PHPUnit artefacts. This clean path is intentionally
# independent from discovery-cache prerequisites so base clean can delete
# .makefiles without being recreated mid-run.
clean::
	@coverage_dir="coverage"; \
	project_root="$(MF_PROJECT_ROOT)"; \
	project_root=$${project_root%/}; \
	remove_script="$(MF_MODULES_ROOT)core/remove-with-guardrails.sh"; \
	if [ ! -f "$$remove_script" ] && [ -f "/tmp/mf-remove-with-guardrails.sh" ]; then \
		remove_script="/tmp/mf-remove-with-guardrails.sh"; \
	fi; \
	if [ ! -f "$$remove_script" ]; then \
		echo "[phpunit] missing guardrails helper script" >&2; \
		exit 1; \
	fi; \
	if [ -f "$(MF_PROJECT_ROOT)phpunit.xml" ]; then \
		configured_coverage=$$(grep -Eo 'outputDirectory="[^"]+"' "$(MF_PROJECT_ROOT)phpunit.xml" | head -n1 | sed -E 's/outputDirectory="([^"]+)"/\1/'); \
		if [ -n "$$configured_coverage" ]; then \
			coverage_dir="$$configured_coverage"; \
		fi; \
	fi; \
	case "$$coverage_dir" in \
		/*) ;; \
		*) coverage_dir="$(MF_PROJECT_ROOT)$$coverage_dir" ;; \
	esac; \
	sh "$$remove_script" "$$project_root" phpunit dir "$$coverage_dir"; \
	sh "$$remove_script" "$$project_root" phpunit dir "$(MF_PROJECT_ROOT).phpunit.cache"; \
	sh "$$remove_script" "$$project_root" phpunit file "$(MF_PROJECT_ROOT).phpunit.result.cache"