# makefiles

> Reusable GNU Make modules for Composer, Docker, PHP, and whatever else you need on a project.

This repository hosts the canonical makefiles published at `https://darianbr.github.io/makefiles`. They are designed to be human-readable for contributors and machine-friendly for tools like Copilot.

## Overview
- **Modular**: each module under `modules/` exposes its own `Makefile` plus optional helper `.mk` fragments.
- **Bootstrap-friendly**: the `fetch` script and a local `make` pattern rule automatically populate `.makefiles/` with the modules you need, on first use.
- **Consistent**: every makefile carries a `Last edited` header and includes the shared root logic so targets behave the same way across projects.

## Getting Started
1. Ensure you have GNU Make, `curl`, and any runtime the module requires (e.g., PHP for Composer) installed.
2. In your project's `Makefile`, include the module and add a bootstrap rule that downloads it on first use:

```makefile
-include .makefiles/modules/composer/Makefile

# Pull the composer module (and the shared root Makefile) the first time it's needed.
.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

3. Run `make <target>` as usual; the first invocation pulls the requested module into `.makefiles/modules/`. Subsequent runs skip the download.

## Usage Examples
### Composer-focused Project
```makefile
-include .makefiles/modules/composer/Makefile

# Bootstrap: pull the composer module (and root Makefile) on first use.
.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

`make install` runs Composer's install; `make clean` removes `vendor/` and the `.makefiles/` cache.

### Multi-module (Composer + Docker)
```makefile
-include .makefiles/modules/composer/Makefile
-include .makefiles/modules/docker/Makefile

# Bootstrap: pull any requested module on first use.
.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

`make install` runs Composer's install; `make clean` runs every module's clean (root + composer + docker) because they all use double-colon (`::`) targets.

## Repository Layout
- `modules/` – source makefiles for every module.
  - `modules/Makefile` – root: shared `MF_*` path variables and the base `clean::` target.
  - `modules/<module>/Makefile` – module entry targets (`install::`, `clean::`, ...).
  - `modules/<module>/*.mk` – optional helper fragments (header + guard only, no root include).
  - `modules/manifest.txt` – lists every published file (one path per line); `fetch` uses it to know what to download.
- `.makefiles/` – generated cache inside consuming projects; mirrors the structure under `modules/`.
- `fetch` – helper script that downloads the requested module over HTTPS.
- `CONTRIBUTIONS.md` – rules for adding or editing modules.

## PHPUnit (Git submodule)
PHPUnit is vendored as a Git submodule at `phpunit/` (pinned to a release tag). After cloning, initialize it with:

```bash
git submodule update --init --recursive
```

Then invoke it directly (requires PHP >= 8.4.1):

```bash
php phpunit/phpunit --version
php phpunit/phpunit path/to/tests
```

Note: this submodule is a standalone checkout for running tests. If a consuming project manages PHPUnit through Composer, keep that dependency as-is; the submodule does not replace it.

## Contributing
Please read [CONTRIBUTIONS.md](CONTRIBUTIONS.md) before opening a PR. It covers directory layout, header requirements, and how to structure module-specific targets so they compose cleanly. Remember to add any new file to `modules/manifest.txt` so `fetch` can download it.

## Support
If you spot a bug or have an idea for a new module, open an issue or start a discussion. When filing bugs, include the target you ran, the module(s) involved, and any console output so we can reproduce it quickly.
