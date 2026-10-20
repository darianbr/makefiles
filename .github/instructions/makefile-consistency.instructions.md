---
applyTo: 'modules/**/*.mk, modules/**/Makefile'
---

All files under the `modules/` directories are files that make up a module. A module is a collection of files that provide reusable functionality for various programming languages and tools.

## Terms and Definitions

### Root Makefiles
The root `modules/Makefile` provides shared functionality and variables for all Makefiles under their respective module directories.

### Modules
- Folders directly under `modules/` define modules (e.g., `composer`, `docker`, `phpunit`, etc.).
- Each module **must** contain a file named `Makefile` at the base of the module folder (e.g. `modules/<module>/Makefile`).
- Every `modules/<module>/Makefile` **must** include the root Makefile located at `modules/Makefile` directly after the header (see Headers below) leaving a blank line.
- Additional Makefile targets for the module can be included in module folder, **must** be suffixed `*.mk`, **must** include the header (see Headers below) and must not include the root library Makefile. An example is `modules/composer/install-binary.mk`.
- Module-specific helper scripts may live under `modules/<module>/*.sh` (for example config/path discovery helpers). Keep module behavior module-local; core files should remain module-agnostic.
- All module files under `modules/**/*` **must always** follow the instructions outlined in the header section below.

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
macro. Keep the registration list in sync when adding, renaming, or removing
public targets, including targets defined by helper `.mk` files. Do not list
private prerequisites as public targets. Example:

```
MF_CURRENT_MODULE_ENTRY := $(lastword $(filter-out %/modules/Makefile,$(MAKEFILE_LIST)))
$(eval $(call mf_register_module,$(MF_CURRENT_MODULE_ENTRY),echopath test coverage coverage-open))
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
resolved values under `.makefiles/.cache/` and make path-dependent targets
(such as `coverage`, `coverage-open`, and `clean`) depend on that cache file.
This ensures all related targets use the same resolved path.

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
- **Module helper script** (`modules/<module>/*.sh`) — optional shell helper for module-local behavior. Use module ownership for config parsing logic rather than adding module-aware logic to core.

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

## Example Structure for Library Modules

modules/
  ├── composer/               # Composer module
  │   ├── Makefile            # Module Makefile (includes header and root include)
  │   └── install-binary.mk   # Helper fragment (header and guard only)
  │   └── discover-paths.sh   # Optional module helper script
  ├── docker/                 # Docker placeholder module
  │   └── Makefile            # Module Makefile (includes header and root include)
  └── phpunit/                # PHPUnit test and coverage module
      ├── Makefile            # Module Makefile (includes header and root include)
      ├── install-binary.mk   # Optional standalone PHPUnit PHAR installer
      └── discover-paths.sh   # Optional module helper script