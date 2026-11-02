# makefiles

> Reusable GNU Make modules for Composer, Docker, PHPUnit, and whatever else you need on a project.

This repository hosts the canonical makefiles published at `https://darianbr.github.io/makefiles`. They are designed to be human-readable for contributors and machine-friendly for tools like Copilot.

## Overview
- **Modular**: the required consumer-module layout is an entry `Makefile`, a `prerequisites.mk`, and a `targets.mk`, plus optional module-local helpers.
- **Bootstrap-friendly**: the `fetch` script and a local `make` pattern rule automatically populate `.makefiles/` with the modules you need, on first use.
- **Config-aware**: modules can derive runtime paths from project config files (for example `codeception.yml` and `phpunit.xml`) and cache resolved values under `.makefiles/cache/`.
- **Consistent**: every module file carries a `Last edited` header; module entry points load the shared root logic and helper fragments use the same guard convention, so targets behave the same way across projects.

## Architecture Decisions
- **Module ownership over shared abstractions**: module-specific behavior belongs in the owning module directory (for example `modules/codeception/` and `modules/phpunit/`), not in shared core files.
- **Discovery scripts are local to modules**: when a module needs config parsing, keep it in module-local scripts such as `modules/<module>/discover-paths.sh`.
- **Resolved paths are cached once per run context**: modules write discovered runtime paths to `.makefiles/cache/` and path-dependent targets reuse those files.
- **Coverage target consistency is guaranteed by dependencies**: `coverage` and `coverage-open` depend on the same cache artifact so they operate on one resolved path.
- **Self-healing prerequisites at target runtime**: if a module runner binary is missing (for example `vendor/bin/codecept` or `vendor/bin/phpunit`), module prerequisites attempt `make composer install` before failing.
- **Root stays generic**: shared dispatch and path infrastructure in `modules/Makefile` remains module-agnostic.

## Getting Started
1. Ensure you have GNU Make, Bash, `curl`, and any runtime the module requires (e.g., PHP for Composer) installed.
2. In your project's `Makefile`, include the module and add a bootstrap rule that downloads it on first use:

```makefile
-include .makefiles/modules/composer/Makefile

# Pull the composer module (and the shared root Makefile) the first time it's needed.
.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

3. Run `make <target>` as usual; the first invocation pulls the requested module into `.makefiles/modules/`. Subsequent runs skip the download.
4. Add `.makefiles/` to your project's `.gitignore` — it is regenerated on demand and should not be committed.

## Examples First

Prefer starting from [examples/README.md](examples/README.md). Each module has a
standalone MVP under `examples/<module>/` so you can copy only what you need.

- `examples/codeception/`
- `examples/phpunit/`
- `examples/composer/`
- `examples/npm/`
- `examples/rust/`
- `examples/typescript/`
- `examples/vitest/`
- `examples/stacked-tests/`
- `examples/docker/`

## Usage Examples
### Composer-focused Project
```makefile
-include .makefiles/modules/composer/Makefile

# Bootstrap: pull the composer module (and root Makefile) on first use.
.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

`make install` runs Composer's install; `make clean` removes `vendor/` (only when `composer.lock` is present) and `.makefiles/` (including `.makefiles/cache/`).

### Multi-module (Composer + Docker)
```makefile
-include .makefiles/modules/composer/Makefile
-include .makefiles/modules/docker/Makefile

# Bootstrap: pull any requested module on first use.
.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

`make install` runs Composer's install; `make clean` runs every module's clean (root + composer + docker) because they all use double-colon (`::`) targets. Note the docker module is currently a placeholder — its `clean::` only prints a line and it has no build targets yet.

## Aggregate and Module-Scoped Targets

The normal one-argument form, `make <target>`, is a convenience command for
all imported modules plus any shared root contribution. It runs that target
wherever a module defines it, in the same import order used by the aggregate
targets. For example, with `npm`,
`composer`, and `docker` imported, `make build` runs the `build` contribution
from every imported module that provides one.

The exact two-argument form, `make <module> <target>`, selects one imported
module and runs only its target:

```console
# Aggregate: runs npm build, composer build, and any other imported build.
$ make build

# Scoped: runs npm's build only.
$ make npm build

# Scoped: runs composer's build only.
$ make composer build
```

The `npm` and `build` examples assume the consumer has imported an npm module
and that both modules expose a `build` target. The currently published modules
in this repository are `codeception`, `composer`, `docker`, `npm`, `phpunit`,
`rust`, `typescript`, and `vitest`; Composer does not expose `build`.
Consequently, `make composer build` in a consumer using the published Composer
module fails validation before running any recipe. Scoped examples include
`make composer install`, `make npm install`, and `make docker clean`. The npm
install target runs `npm ci` when `package-lock.json` or `npm-shrinkwrap.json`
is present, and falls back to `npm install` when only `package.json` is present.

Scoped validation errors are written to stderr and return status 2. An unknown
module identifies the requested name and lists imported modules:

```text
makefiles: unknown module 'missing'; imported modules: composer docker
makefiles: usage: make <target> | make <module> <target>
```

An unavailable target identifies the selected module and lists its available
targets:

```text
makefiles: target 'build' is not available in module 'composer'; available targets: clean echopath help install install-composer-binary
```

Validation happens before module recipes run. The exact two-goal form is
reserved for module dispatch, so `make name target` is not treated as two
independent aggregate goals. Set `MF_LEGACY_GOALS=1` only when a consumer needs
the pre-feature two-goal GNU Make interpretation.

### Module names and public target registration

Every public module-specific target is available in the module's namespace as
`make <module> <target>`. `<module>` is the directory name under `modules/`
(for example, `make phpunit test` or `make composer install`), and `<target>`
is the ordinary Make target name. A module is eligible only when the consumer
explicitly includes its entry Makefile; a cached but unreferenced module is
not selectable. Register the standard `clean`, `install`, and `help` targets,
plus all module-specific public targets, in the entry Makefile. Keep prerequisite
configuration in `prerequisites.mk` and all target rules and recipes in
`targets.mk`; optional helper `.mk` files must not define targets. The
contributor workflow and required registration pattern are in
[CONTRIBUTIONS.md](CONTRIBUTIONS.md); this README section is the canonical
reference for invocation and compatibility behavior.

Keep the one-argument interface intact: `make <target>` continues to aggregate
the target across imported modules in GNU Make import order, and shared root
contributions remain available there. The exact two-goal form is the only
reserved form for scoped dispatch; consumers that previously used two
independent goals in that form can opt out with `MF_LEGACY_GOALS=1`. Invocations
with one goal or more than two goals retain their existing interpretation.

Consumers can run a setup target before selected scoped invocations by setting
`MF_DISPATCH_SETUP` to the target name and listing applicable `module:target`
pairs in `MF_DISPATCH_SETUP_PAIRS`. The setup target runs only for those pairs,
before the selected module target.

## Module Targets

Every consumer module is required to expose `clean`, `install`, and `help`,
using an explicit no-op with a useful message when a target has no work. See
[CONTRIBUTIONS.md](CONTRIBUTIONS.md) for the required file layout. The table
below documents target behavior; it is not an audit that every existing module
already complies.

| Module | Target | Behavior |
|--------|--------|----------|
| (root) | `clean::` | Removes `.makefiles/` (including `.makefiles/cache/`); skips when absent. |
| codeception | `echopath::` | Diagnostic: prints the module name, resolved `MF_*` paths, Codeception executable, and coverage directory. |
| codeception | `test::` | Runs the Composer-installed Codeception executable. |
| codeception | `coverage::` | Runs Codeception with HTML coverage output in the path resolved from `codeception.yml` (`paths.output`) plus `/coverage` (fallback: `_output/coverage`). |
| codeception | `coverage-open::` | Regenerates the HTML coverage report and opens it with `BROWSER`, `xdg-open`, or `open`. |
| codeception | `clean::` | Removes Codeception suite artefacts: coverage output, support output, and main output directory (resolved from `codeception.yml`; fallbacks `_output/coverage`, `_support`, `_output`). |
| composer | `install::` | Runs `composer install` in the project root. First provisions `composer.phar` into `.makefiles/tools/` (via `install-composer-binary`). |
| composer | `clean::` | Removes `vendor/` — only when both `vendor/` and `composer.lock` exist; otherwise prints a skip message. |
| composer | `echopath::` | Diagnostic: prints the module name and the resolved `MF_*` paths. |
| composer | `install-composer-binary` | Downloads the Composer installer, verifies its SHA-384 signature, and installs `composer.phar` into `.makefiles/tools/`. |
| docker | `echopath::` | Diagnostic: prints the module name and the resolved `MF_*` paths. |
| docker | `clean::` | Stub: prints a line only. The docker module is a placeholder with no real targets yet. |
| npm | `echopath::` | Diagnostic: prints the module name, resolved `MF_*` paths, and npm executable. |
| npm | `install::` | Runs `npm ci` in the project root when `package-lock.json` or `npm-shrinkwrap.json` exists; otherwise runs `npm install` when only `package.json` is present. Set `NPM` or `NPM_INSTALL_ARGS` to customize the command. |
| npm | `clean::` | Removes generated directories listed in `NPM_CLEAN_DIRS` (defaults: `node_modules`, `dist`, `build`, `coverage`, `.next`, `.nuxt`, `.output`); leaves source files and lockfiles untouched. |
| phpunit | `echopath::` | Diagnostic: prints the module name, resolved `MF_*` paths, PHPUnit executable, and coverage directory. |
| phpunit | `install-phpunit-binary` | Downloads the optional standalone PHPUnit PHAR into `.makefiles/tools/` (or `PHPUNIT_PHAR`). |
| phpunit | `test::` | Runs the Composer-installed PHPUnit executable against the project test suite. |
| phpunit | `coverage::` | Runs PHPUnit with `--coverage-html` and writes the report to the path resolved from `phpunit.xml` HTML report config (fallback: `coverage/`). |
| phpunit | `coverage-open::` | Regenerates the HTML coverage report and opens `coverage/index.html` with `BROWSER`, `xdg-open`, or `open`. |
| phpunit | `clean::` | Removes PHPUnit suite artefacts: HTML coverage output (resolved from `phpunit.xml` or fallback `coverage/`), `.phpunit.cache`, and `.phpunit.result.cache`. |
| rust | `echopath::` | Diagnostic: prints the module name, resolved `MF_*` paths, cargo executable, and target directory. |
| rust | `build::` | Runs `cargo build` in the project root. Set `CARGO_BUILD_ARGS` to pass extra flags (for example `--release`). |
| rust | `test::` | Runs `cargo test` in the project root. Set `CARGO_TEST_ARGS` to pass extra flags. |
| rust | `clippy::` | Runs `cargo clippy` in the project root. Set `CARGO_CLIPPY_ARGS` to pass extra flags (for example `-- -D warnings`). |
| rust | `fmt::` | Runs `cargo fmt` in the project root. Set `CARGO_FMT_ARGS` to pass extra flags (for example `-- --check`). |
| rust | `clean::` | Removes the cargo target directory through shared clean guardrails. The effective directory is resolved from `cargo metadata` (honoring `CARGO_TARGET_DIR` and `.cargo/config.toml`) with a fallback to `target`. |
| typescript | `echopath::` | Diagnostic: prints the module name, resolved `MF_*` paths, npm executable, and TypeScript configuration values. |
| typescript | `build::` | Runs TypeScript compilation using the configured project file (default `tsconfig.json`) and output directory (default `build/typescript`). |
| typescript | `test::` | Runs TypeScript type-check mode (`--noEmit`) using the configured project file. |
| typescript | `clean::` | Removes TypeScript build artefacts (`build/typescript` and `.tsbuildinfo`) through shared clean guardrails. |
| vitest | `echopath::` | Diagnostic: prints the module name, resolved `MF_*` paths, Vitest executable, and configured coverage directory. |
| vitest | `test::` | Runs Vitest in run mode (`vitest run`). |
| vitest | `coverage::` | Runs Vitest with HTML coverage output (default directory `coverage/vitest`). |
| vitest | `coverage-open::` | Regenerates the HTML coverage report and opens it with `BROWSER`, `xdg-open`, or `open`. |
| vitest | `clean::` | Removes Vitest coverage output through shared clean guardrails. |

Aggregate-contributing targets use double-colon (`::`) so multiple modules can contribute to the same target name. `make clean` runs the shared root cleanup and the `clean::` recipes from every imported module that defines them, in import order; for the Composer + Docker example above, that is root + composer + docker. The Codeception, PHPUnit, and Composer clean recipes are independent and do not invoke one another.

## Repository Layout

The module paths below describe the required convention, not a compliance
inventory of the existing modules.

- `modules/` – canonical source makefiles.
  - `modules/Makefile` – root: shared `MF_*` path variables and base `clean::` target.
  - `modules/<module>/Makefile` – module entry point, includes the root and registers public targets.
  - `modules/<module>/prerequisites.mk` – required module prerequisite configuration.
  - `modules/<module>/targets.mk` – required module target rules and recipes.
  - `modules/<module>/*.mk` – optional non-target helper fragments (header + guard only, no root include).
  - `modules/<module>/*.sh` – optional module-owned discovery helpers for config-derived paths.
  - `modules/core/` – shared infrastructure; it is not a consumer module.
  - `modules/manifest.txt` – lists every published file (one path per line); `fetch` uses it to know what to download.
- `.makefiles/` – generated runtime folder inside consuming projects. Holds two subtrees: `.makefiles/modules/` (the fetched makefiles, mirroring `modules/`) and `.makefiles/tools/` (provisioned binaries, e.g. `composer.phar`).
- `.makefiles/cache/` – generated project cache folder for resolved runtime paths used by module targets.
- `examples/` – standalone per-module MVP projects for quick adoption in downstream repositories.
- `fetch` – helper script that downloads the requested module **and the shared root Makefile** over HTTPS.
- `CONTRIBUTIONS.md` – rules for adding or editing modules.

## `fetch` Reference

The `fetch` script (hosted at `https://darianbr.github.io/makefiles/fetch`) downloads a module into the local `.makefiles/modules/` cache.

```bash
fetch <module> [--force]
```

- `<module>` — module name, e.g. `codeception`, `composer`, `docker`, `npm`, `phpunit`, `rust`, `typescript`, or `vitest`. Must match a folder under `modules/` listed in `modules/manifest.txt`.
- `--force` — refetch even if the module is already present.

Behavior:
- **Idempotent**: if `.makefiles/modules/<module>/Makefile` already exists, `fetch` exits without touching the network (use `--force` to refetch).
- **Downloads**: the shared root `Makefile`, all `core/*` shared files, plus every file the manifest assigns to the requested module.
- **`MAKEFILES_BASE_URL`**: override the base URL (default `https://darianbr.github.io/makefiles/modules`) — useful for testing against a local server.
- **Errors**: exits non-zero if no module name is given, if the module is not in the manifest, or if any download fails (`curl -sf`).

## PHPUnit
PHPUnit is available as a native module under `modules/phpunit/`. It expects the
consuming project to install PHPUnit through Composer at `vendor/bin/phpunit`.
Include the module using the same bootstrap pattern as the other modules:

```makefile
-include .makefiles/modules/phpunit/Makefile

.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

After `composer install`, the module provides:

```console
make test
make coverage
make coverage-open
```

`coverage` writes its HTML report to the directory configured in
`phpunit.xml` (`<coverage><report><html outputDirectory="..."/>`), or defaults
to `coverage/` when no HTML report directory is configured. Set
`BROWSER=firefox` (or another opener command) to choose how `coverage-open`
launches the report. Relative executable and report paths are resolved from the
consuming project root. Missing PHP or browser-opener dependencies fail with an
actionable error instead of running a partial workflow. If `vendor/bin/phpunit`
is missing, the module attempts `make composer install` automatically before
failing.

For projects that need a standalone PHPUnit PHAR, run
`make phpunit install-phpunit-binary`. The PHAR is cached at
`.makefiles/tools/phpunit.phar` by default; set `PHPUNIT_PHAR` to change its
location, `PHPUNIT_VERSION` to request a versioned PHAR, or `PHPUNIT_URL` to
provide a custom download URL. This target is opt-in and does not replace the
Composer-installed `PHPUNIT` default. Set `PHPUNIT` explicitly when the test
workflow should execute the cached PHAR.

## Codeception

The Codeception module runs the Composer-installed `vendor/bin/codecept`
executable in a consuming project. Install Codeception and configure at least
one suite before using the module:

```sh
composer require --dev codeception/codeception
vendor/bin/codecept bootstrap
```

Include the module with the usual bootstrap rule:

```makefile
-include .makefiles/modules/codeception/Makefile

.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

Then run the standard workflows from the project root:

```console
make test          # codecept run
make coverage      # HTML report in the discovered coverage path (fallback _output/coverage)
make coverage-open # regenerate and open the HTML report
```

`CODECEPTION_ARGS` passes additional arguments to Codeception. Use `CODECEPTION`
and `PHP` to override executable paths. The coverage output directory is
resolved from `codeception.yml` (`paths.output`) and defaults to
`_output/coverage` when no output path is configured. `BROWSER` selects
the opener for `coverage-open`. The module requires PHP and attempts to install
Composer dependencies automatically when the Codeception executable is missing.

Both Codeception and PHPUnit write their discovered coverage directories to
cache files under `.makefiles/cache/` so related coverage targets use exactly
the same resolved path:

- `.makefiles/cache/codeception-coverage-dir`
- `.makefiles/cache/phpunit-coverage-dir`

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `MF_TOOLS_ROOT is not set. Include modules/Makefile ...` | The shared root Makefile didn't download (network failure, site down, or a partial cache), so the module guard fires. | Run `fetch <module> --force`, or delete `.makefiles/` and retry the target. Check that `https://darianbr.github.io/makefiles` is reachable. |
| `fetch` fails mid-download (`curl` error, partial files) | Network hiccup or the Pages site was mid-rebuild. | Re-run `fetch <module> --force`. If it persists, check the site is up and your network. |
| `ERROR: Invalid installer signature` when provisioning Composer | The downloaded Composer installer doesn't match the published SHA-384 signature (corrupted download or tampering). | Re-run `make install` (the installer files are deleted and re-downloaded). If it repeats, check your network/proxy. |
| `make install` fails: no `composer.json` | The composer module runs `composer install` in your project root, which requires a `composer.json` there. | Add a `composer.json` to the project root, or run the target from a directory that has one. |
| `[typescript] project file not found` | `TSC_PROJECT` does not exist in the project root. | Create the project file, or set `TSC_PROJECT` to a valid relative path (for example `tsconfig.build.json`). |
| `make typescript test` reports missing Node types or lib symbols | TypeScript project settings/dependencies are incomplete for your runtime. | Install required type packages (for example `@types/node`) and align `compilerOptions.types`/`lib` in the chosen TS config. |
| `[vitest] Vitest executable not found` | Vitest is not installed in project dependencies and no global binary is available. | Add `vitest` (and optional coverage provider package) to dev dependencies, or override `VITEST_BIN` to a valid path. |
| `make phpunit install-phpunit-binary` fails | The standalone PHAR download URL is unavailable or invalid. | Check network access, or set `PHPUNIT_VERSION`/`PHPUNIT_URL` to a valid PHPUnit PHAR source. |
| `[phpunit] PHP executable not found` or `[phpunit] PHPUnit executable not found` | PHP is not installed, or Composer has not installed `vendor/bin/phpunit`. | Install PHP and run `composer install`, or override `PHP`/`PHPUNIT` with paths available to the project. |
| `No coverage driver detected` (phpunit/codeception coverage) | Neither `xdebug` nor `pcov` is enabled in the active PHP runtime. | Install/enable `xdebug` or `pcov`; for xdebug, use `XDEBUG_MODE=coverage` when running coverage targets. |
| `[phpunit] Browser opener not found` or `No browser opener found` | `BROWSER`, `xdg-open`, and `open` are unavailable. | Install/configure a browser opener, set `BROWSER` to its executable, or open `coverage/index.html` manually. |

**How the bootstrap works.** Your Makefile `-include`s the module file and defines a pattern rule for `.makefiles/modules/%/Makefile`. On the first run the module file is missing, so `make` runs the rule, which pipes `fetch` over `curl` to download the module (and the shared root Makefile) into `.makefiles/modules/`. `make` then re-reads the Makefile and continues with the real target. Later runs find the module file already present, so no download happens.

## Contributing
Please read [CONTRIBUTIONS.md](CONTRIBUTIONS.md) before opening a PR. It covers directory layout, header requirements, and how to structure module-specific targets so they compose cleanly. Remember to add any new file to `modules/manifest.txt` so `fetch` can download it.

## Support
If you spot a bug or have an idea for a new module, open an issue or start a discussion. When filing bugs, include the target you ran, the module(s) involved, and any console output so we can reproduce it quickly.
