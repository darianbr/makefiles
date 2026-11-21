#
# Filename: modules/wtree/targets.mk
# Last edited: 2026-11-20
# Description: Public local worktree proxy targets.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/wtree/targets.mk.)
endif

ifndef MF_WTREE_TARGETS_INCLUDED
MF_WTREE_TARGETS_INCLUDED := 1

.PHONY: help install clean up down status

install:: mf-wtree-ensure
	@echo '[wtree] binary ready'

up::
	@if [ -z "$$WTREE_PORT" ]; then echo '[wtree] WTREE_PORT is required for up' >&2; exit 1; fi
	@$(MAKE) --no-print-directory -f .makefiles/modules/wtree/Makefile mf-wtree-ensure
	@case "$$WTREE_BIN" in */*) ;; *) WTREE_BIN="./$$WTREE_BIN" ;; esac; \
	if [ -n "$$WTREE_SLUG" ]; then \
		"$$WTREE_BIN" up --port "$$WTREE_PORT" --slug "$$WTREE_SLUG"; \
	else \
		"$$WTREE_BIN" up --port "$$WTREE_PORT"; \
	fi

down:: mf-wtree-ensure
	@case "$$WTREE_BIN" in */*) ;; *) WTREE_BIN="./$$WTREE_BIN" ;; esac; \
	if [ -n "$$WTREE_SLUG" ]; then \
		"$$WTREE_BIN" down --slug "$$WTREE_SLUG"; \
	else \
		"$$WTREE_BIN" down; \
	fi

status:: mf-wtree-ensure
	@case "$$WTREE_BIN" in */*) ;; *) WTREE_BIN="./$$WTREE_BIN" ;; esac; \
	"$$WTREE_BIN" status

clean::
	@echo '[wtree] clean skipped (active routes and proxy are unchanged)'

endif