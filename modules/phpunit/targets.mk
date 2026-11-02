#
# Filename: modules/phpunit/targets.mk
# Last edited: 2026-11-02 18:27:36
# Description: PHPUnit module target recipes.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/phpunit/targets.mk.)
endif

ifndef MF_PHPUNIT_TARGETS_INCLUDED
MF_PHPUNIT_TARGETS_INCLUDED := 1

.PHONY: help echopath test coverage coverage-open clean install install-phpunit-binary

help::
	@printf '%s\n' 'phpunit targets: $(MF_MODULE_TARGETS_phpunit)'

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

test:: phpunit-prerequisites
	@cd "$(MF_PROJECT_ROOT)" && \
	if [ -f "$(PHPUNIT)" ]; then \
		"$(PHP)" "$(PHPUNIT)" $(PHPUNIT_ARGS); \
	else \
		"$(PHPUNIT)" $(PHPUNIT_ARGS); \
	fi

install:: phpunit-prerequisites
	@echo "[phpunit] PHPUnit prerequisites are ready"

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

install-phpunit-binary:
	@set -eu; \
	mkdir -p "$$(dirname "$(PHPUNIT_PHAR)")"; \
	if [ -f "$(PHPUNIT_PHAR)" ]; then \
		echo "[phpunit] PHPUnit binary already present: $(PHPUNIT_PHAR)"; \
	else \
		tmp="$(PHPUNIT_PHAR).tmp"; \
		trap 'rm -f "$$tmp"' EXIT; \
		curl -fsSL "$(PHPUNIT_URL)" -o "$$tmp"; \
		chmod +x "$$tmp"; \
		mv "$$tmp" "$(PHPUNIT_PHAR)"; \
		echo "[phpunit] PHPUnit binary installed: $(PHPUNIT_PHAR)"; \
	fi

$(MF_PHPUNIT_PHAR_TARGET):
	@$(MAKE) install-phpunit-binary

endif