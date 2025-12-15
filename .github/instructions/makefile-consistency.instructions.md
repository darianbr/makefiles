---
applyTo: 'modules/**/*.mk, modules/**/Makefile'
---

All files under the `modules/` directories are files that make up a module. A module is a collection of files that provide reusable functionality for various programming languages and tools.

## Terms and Definitions

### Root Makefiles
The root `modules/Makefile` provide shared functionality and variables for all Makefiles under their respective module directories.

### Modules
- Folders directly under `modules/` define modules (e.g., `php`, `docker`, `composer`, `npm`, etc.).
- Each module **must** contain a file named `Makefile` at the base of the module folder (e.g. `modules/<module>/Makefile`).
- Every `modules/<module>/Makefile` **must** include the root Makefile located at `modules/Makefile` directly after the header (see Headers below) leaving a blank line.
- Additional Makefile targets for the module can be included in module folder, **must** be suffixedd `*.mk`, **must** include the header (see Headers below) and must not include the root library Makefile. An example would be `modules/php/clean.mk` or `modules/npm/install.mk`.
- All module files under `modules/**/*` **must always** follow the insturctions outlined in the header section below.

## Headers
All module files under `modules/**/*` **must always** contain a header as the first lines like so:
```
#
# Filename: <filename>
# Last edited: <YYYY-MM-DD> <HH:MM:SS>
# Description: <Short description of the file's purpose>
#
<blank line>
ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using <filename>.)
endif
<blank line>
```

- Run the command `date -r <filename> +'%Y-%m-%d %H:%M:%S'` to get the Last Edited date and time for `<YYYY-MM-DD> <HH:MM:SS>`.
- The `<filename>` field **must** be the relative path to the file from the project root.
- The `<Short description of the file's purpose>` field **must** be a brief summary of what the file does.
- There **must** be a single blank line after the header before any other content.

## Required Makefile Includes

All Makefiles matching `modules/**/Makefile` **must** include the root Makefile located at `modules/Makefile` directly after the header with exactly one blank line between them.

For example, a module with Makefile `modules/php/Makefile` would include the following lines immediately after the header:
```
-include .makefiles/modules/Makefile
```

## Example Structure for Library Modules

modules/
  ├── docker/                 # Docker library module
  │   ├── Makefile            # Module Makefile (includes header and root include)
  │   ├── clean.mk            # Additional targets and functionality
  │   └── build.mk            # Additional targets and functionality
  ├── php/                    # PHP library module
  │   ├── Makefile            # Module Makefile (includes header and root include)
  │   └── install.mk          # Additional targets and functionality
  └── npm/                    # NPM library module
      ├── Makefile            # Module Makefile (includes header and root include)
      └── link.mk             # Additional targets and functionality