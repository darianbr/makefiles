#
# Filename: modules/codeception/targets.mk
# Last edited: 2026-10-20 18:10:00
# Description: Codeception module target recipes.
#

MF_CODECEPTION_PATH_DISCOVERY_SCRIPT := $(MF_MODULES_ROOT)codeception/discover-paths.sh
MF_CODECEPTION_COVERAGE_CACHE_PATH := $(MF_CACHE_ROOT)codeception-coverage-dir
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

echopath:: $(MF_CODECEPTION_COVERAGE_CACHE_PATH)
	@echo "Codeception module Makefile"
	@echo "MF_PROJECT_ROOT: $(MF_PROJECT_ROOT)"
	@echo "MF_MAKEFILES_ROOT: $(MF_MAKEFILES_ROOT)"
	@echo "MF_MODULES_ROOT: $(MF_MODULES_ROOT)"
	@echo "MF_TOOLS_ROOT: $(MF_TOOLS_ROOT)"
	@echo "CODECEPTION: $(CODECEPTION)"
	@echo "CODECEPTION_CONFIG: $(MF_CODECEPTION_CONFIG_FILE)"
	@coverage_dir=$$(cat "$(MF_CODECEPTION_COVERAGE_CACHE_PATH)"); echo "CODECEPTION_COVERAGE_DIR: $$coverage_dir"
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

coverage:: codeception-ready $(MF_CODECEPTION_COVERAGE_CACHE_PATH)
	@coverage_dir=$$(cat "$(MF_CODECEPTION_COVERAGE_CACHE_PATH)"); \
	if ! (cd "$(MF_PROJECT_ROOT)" && "$(PHP)" -m | grep -qiE '^(xdebug|pcov)$$'); then \
		echo "[codeception] No coverage driver detected. Install and enable xdebug or pcov for line coverage." >&2; \
		echo "[codeception] Hint: xdebug users may also need XDEBUG_MODE=coverage." >&2; \
		if [ -n "$(MF_SCOPED_MODULE)" ]; then \
			exit 1; \
		fi; \
		echo "[codeception] skipping coverage in aggregate mode"; \
		exit 0; \
	fi; \
	cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(CODECEPTION)" ]; then \
		if "$(PHP)" -m | grep -qi '^xdebug$$'; then \
			XDEBUG_MODE=coverage "$(PHP)" "$(CODECEPTION)" run --coverage --coverage-html "$$coverage_dir" $(CODECEPTION_ARGS); \
		else \
			"$(PHP)" "$(CODECEPTION)" run --coverage --coverage-html "$$coverage_dir" $(CODECEPTION_ARGS); \
		fi; \
	else \
		if "$(PHP)" -m | grep -qi '^xdebug$$'; then \
			XDEBUG_MODE=coverage "$(CODECEPTION)" run --coverage --coverage-html "$$coverage_dir" $(CODECEPTION_ARGS); \
		else \
			"$(CODECEPTION)" run --coverage --coverage-html "$$coverage_dir" $(CODECEPTION_ARGS); \
		fi; \
	fi

coverage-open:: coverage
	@coverage_dir=$$(cat "$(MF_CODECEPTION_COVERAGE_CACHE_PATH)"); \
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

# Remove suite-generated Codeception directories. This clean path is intentionally
# independent from discovery-cache prerequisites so base clean can delete
# .makefiles without being recreated mid-run.
clean::
	@output_dir="_output"; \
	support_dir="_support"; \
	if [ -f "$(MF_PROJECT_ROOT)codeception.yml" ]; then \
		configured_output=$$(grep -E '^[[:space:]]*output:[[:space:]]*' "$(MF_PROJECT_ROOT)codeception.yml" | head -n1 | cut -d: -f2- | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$$//' | tr -d '"' | tr -d "'"); \
		configured_support=$$(grep -E '^[[:space:]]*support:[[:space:]]*' "$(MF_PROJECT_ROOT)codeception.yml" | head -n1 | cut -d: -f2- | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$$//' | tr -d '"' | tr -d "'"); \
		if [ -n "$$configured_output" ]; then \
			output_dir="$$configured_output"; \
		fi; \
		if [ -n "$$configured_support" ]; then \
			support_dir="$$configured_support"; \
		fi; \
	fi; \
	case "$$output_dir" in \
		/*) ;; \
		*) output_dir="$(MF_PROJECT_ROOT)$$output_dir" ;; \
	esac; \
	case "$$support_dir" in \
		/*) ;; \
		*) support_dir="$(MF_PROJECT_ROOT)$$support_dir" ;; \
	esac; \
	coverage_dir="$$output_dir/coverage"; \
	for cleanup_path in "$$coverage_dir" "$$support_dir" "$$output_dir"; do \
		if [ -d "$$cleanup_path" ]; then \
			echo "[codeception] removing $$cleanup_path"; \
			rm -rf "$$cleanup_path"; \
		else \
			echo "[codeception] skipping $$cleanup_path (not found)"; \
		fi; \
	done