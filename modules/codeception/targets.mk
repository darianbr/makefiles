#
# Filename: modules/codeception/targets.mk
# Last edited: 2026-11-04 20:19:22
# Description: Codeception module target recipes.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/codeception/targets.mk.)
endif

ifndef MF_CODECEPTION_TARGETS_INCLUDED
MF_CODECEPTION_TARGETS_INCLUDED := 1

.PHONY: help test coverage coverage-open clean install

install:: codeception-prerequisites
	@echo "[codeception] Codeception prerequisites are ready"

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

coverage-open:: $(MF_CODECEPTION_COVERAGE_INDEX_CACHE_PATH)
	@if [ -n "$(BROWSER)" ]; then \
		if ! (cd "$(MF_PROJECT_ROOT)" && command -v "$(BROWSER)" >/dev/null 2>&1); then \
			echo "[codeception] Browser opener not found: $(BROWSER)" >&2; \
			exit 1; \
		fi; \
		coverage_index=$$(cat "$(MF_CODECEPTION_COVERAGE_INDEX_CACHE_PATH)"); \
		cd "$(MF_PROJECT_ROOT)" && "$(BROWSER)" "$$coverage_index"; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		coverage_index=$$(cat "$(MF_CODECEPTION_COVERAGE_INDEX_CACHE_PATH)"); \
		cd "$(MF_PROJECT_ROOT)" && xdg-open "$$coverage_index"; \
	elif command -v open >/dev/null 2>&1; then \
		coverage_index=$$(cat "$(MF_CODECEPTION_COVERAGE_INDEX_CACHE_PATH)"); \
		cd "$(MF_PROJECT_ROOT)" && open "$$coverage_index"; \
	else \
		coverage_index=$$(cat "$(MF_CODECEPTION_COVERAGE_INDEX_CACHE_PATH)"); \
		echo "[codeception] No browser opener found; open $$coverage_index manually." >&2; \
		exit 1; \
	fi

# Remove suite-generated Codeception directories. This clean path is intentionally
# independent from discovery-cache prerequisites so base clean can delete
# .makefiles without being recreated mid-run.
clean::
	@output_dir="_output"; \
	support_dir="_support"; \
	project_root="$(MF_PROJECT_ROOT)"; \
	project_root=$${project_root%/}; \
	remove_script="$(MF_MODULES_ROOT)core/remove-with-guardrails.sh"; \
	if [ ! -f "$$remove_script" ] && [ -f "/tmp/mf-remove-with-guardrails.sh" ]; then \
		remove_script="/tmp/mf-remove-with-guardrails.sh"; \
	fi; \
	if [ ! -f "$$remove_script" ]; then \
		echo "[codeception] missing guardrails helper script" >&2; \
		exit 1; \
	fi; \
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
	sh "$$remove_script" "$$project_root" codeception dir "$$coverage_dir"; \
	sh "$$remove_script" "$$project_root" codeception dir "$$support_dir"; \
	sh "$$remove_script" "$$project_root" codeception dir "$$output_dir"

endif