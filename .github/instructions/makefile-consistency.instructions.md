---
applyTo: 'modules/**/*.mk, modules/**/Makefile, modules/**/*.sh'
---

All files under the `modules/` directories are files that make up a module. A module is a collection of files that provide reusable functionality for various programming languages and tools.

## Terms and Definitions

### Root Makefiles
The root `modules/Makefile` provides shared functionality and variables for all Makefiles under their respective module directories.

### Modules
- Folders directly under `modules/` define modules (e.g., `composer`, `docker`, `phpunit`, `typescript`, `vitest`, etc.).
- Each module **must** contain a file named `Makefile` at the base of the module folder (e.g. `modules/<module>/Makefile`).
- Every `modules/<module>/Makefile` **must** include the root Makefile located at `modules/Makefile` directly after the header (see Headers below) leaving a blank line.
- Each module must include `prerequisites.mk` for prerequisite configuration and `targets.mk` for target definitions and recipes. Both files are module helper fragments: they **must** include the header (see Headers below) and must not include the root library Makefile.
- Optional additional `*.mk` helpers may hold variables, functions, or other non-target support logic. They must include the header, must not include the root library Makefile, and must not define target rules; keep target definitions and recipes in `targets.mk`.
- Module-specific helper scripts may live under `modules/<module>/*.sh` (for example config/path discovery helpers). Keep module behavior module-local; core files should remain module-agnostic.
- Generic shared helper scripts may live under `modules/core/*.sh` when they are module-agnostic (for example reusable path and guardrail helpers).
- All module files under `modules/**/*` **must always** follow the instructions outlined in the header section below.

## Required Module Interface and File Ownership

Every consumer module with an entry Makefile under `modules/<module>/` must
provide the public targets `clean`, `install`, and `help`. This is a required
interface, not a claim that every existing module already complies; inspect and
verify modules before reporting their current status. The shared root and
`modules/core/` infrastructure are not consumer modules.

- `clean` removes only artifacts generated or owned by that module. Guard
  destructive operations and explain a no-op when there is nothing to clean.
- `install` installs or prepares the module's required project dependencies.
  If installation is not applicable, keep the target and print a clear
  no-op message rather than omitting it.
- `help` explains the module's standard and module-specific public targets and
  relevant options without changing project state.

Register all three standard targets, plus every other public target, in the
module entry Makefile's `mf_register_module` call. Define the standard targets
with double-colon rules (`clean::`, `install::`, `help::`) so imported modules
can contribute to aggregate invocations. Keep private prerequisites out of the
public registration list.

Each module entry Makefile includes the required fragments after the root
include and `MF_TOOLS_ROOT` guard, in this order:

```make
-include .makefiles/modules/<module>/prerequisites.mk
-include .makefiles/modules/<module>/targets.mk
```

Keep prerequisite configuration (such as prerequisite-list variables) in
`prerequisites.mk`; it must not define target rules or contain recipe bodies.
Keep all target rules and recipes in `targets.mk`, referring to prerequisite
configuration declared in `prerequisites.mk`. Other `.mk` files may provide
variables or helper functions, but must not define targets. Both required
fragments need the normal header and guard and must be listed in
`modules/manifest.txt`; if a module has no extra prerequisites, an otherwise
empty `prerequisites.mk` is acceptable. Add any newly created files to the
manifest so `fetch` publishes them.

## Public Module Targets and Namespacing

Every public target specific to a module **must** be invocable under that
module's namespace using `make <module> <target>`. The module name is the
directory name under `modules/` (for example, `make phpunit test` for
`modules/phpunit/Makefile`); the target remains its ordinary Make target name.
Only modules whose entry Makefiles are explicitly included by the consumer are
available for scoped dispatch. Do not infer modules from cached directories or
add a central hardcoded module list.

After including the shared root and its guard, each module entry Makefile
**must** register its public targets with the root-provided `mf_register_module`
macro. Keep the registration list in sync with `targets.mk` when adding,
renaming, or removing public targets. Do not list private prerequisites as
public targets. Example:

```
MF_CURRENT_MODULE_ENTRY := $(lastword $(filter-out %/modules/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),clean install help echopath test coverage coverage-open))
```

Use double-colon rules (`target::`) for public targets that should continue to
compose with same-named contributions from other modules in aggregate
`make <target>` mode. Scoped mode (`make <module> <target>`) selects only the
named module's registered target. The one-argument aggregate form remains
unchanged; the exact two-goal form is reserved for scoped dispatch, with
`MF_LEGACY_GOALS=1` available to consumers needing the old interpretation.
For the canonical invocation and compatibility contract, see
[README.md — Aggregate and Module-Scoped Targets](../../README.md#aggregate-and-module-scoped-targets).

When a module derives runtime paths from project config files, it should cache
resolved values under `.makefiles/cache/` and make path-dependent coverage
targets (such as `coverage` and `coverage-open`) depend on that cache file.
This ensures related coverage targets use the same resolved path. Keep module
`clean` targets independent from cache-file prerequisites so base clean can
remove generated folders without forcing `.makefiles/` recreation.

## Headers
All module files under `modules/**/*` **must always** begin with a header as the first lines:
```
#
# Filename: <filename>
# Last edited: <YYYY-MM-DD> <HH:MM:SS>
# Description: <Short description of the file's purpose>
#
```

What follows the header depends on the file type (each part separated by a single blank line):

- **Module `Makefile`** (`modules/<module>/Makefile`) — include the root Makefile, then the guard:
  ```
  -include .makefiles/modules/Makefile

  ifndef MF_TOOLS_ROOT
  $(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using <filename>.)
  endif
  ```
- **Helper fragment** (`modules/<module>/*.mk`) — the guard only (no root include):
  ```
  ifndef MF_TOOLS_ROOT
  $(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using <filename>.)
  endif
  ```
- **Root `modules/Makefile`** — header only; it defines the shared variables and has **no** guard (it *is* the file that sets `MF_TOOLS_ROOT`).
- **Module/helper script** (`modules/<module>/*.sh` and `modules/core/*.sh`) — shell helpers are allowed for module-local behavior and generic shared behavior. Keep module-specific parsing logic in module-owned scripts; keep core scripts module-agnostic.

- Run the command `date -r <filename> +'%Y-%m-%d %H:%M:%S'` to get the Last Edited date and time for `<YYYY-MM-DD> <HH:MM:SS>`.
- The `<filename>` field **must** be the relative path to the file from the project root.
- The `<Short description of the file's purpose>` field **must** be a brief summary of what the file does.
- There **must** be a single blank line after the header before any other content (and between the include and the guard in a module `Makefile`).

## Required Makefile Includes

All module entry Makefiles matching `modules/*/Makefile` **must** include the root Makefile located at `modules/Makefile` directly after the header with exactly one blank line between them. The root `modules/Makefile` is the sole exception because it defines the shared root variables itself.

For example, a module with Makefile `modules/composer/Makefile` would include the following lines immediately after the header:
```
-include .makefiles/modules/Makefile
```

After the root include and guard, the entry Makefile must include the module
fragments in this order:

```make
-include .makefiles/modules/<module>/prerequisites.mk
-include .makefiles/modules/<module>/targets.mk
```

## Required Structure for Library Modules

The tree below describes the required layout; it is not an inventory or a
claim that every existing module already conforms.

modules/
  ├── Makefile                # Shared root Makefile
  ├── manifest.txt            # Every file published by fetch
  └── <module>/               # One consumer module
      ├── Makefile            # Entry point, includes root and registers targets
      ├── prerequisites.mk    # Module prerequisite configuration
      ├── targets.mk          # All target definitions and recipes
      ├── helper.mk           # Optional non-target helper; same header + guard
      └── helper.sh           # Optional module-owned helper script