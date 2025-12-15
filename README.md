# makefiles

> Reusable GNU Make modules for Composer, Docker, PHP, and whatever else you need on a project.

This repository hosts the canonical makefiles published at `https://darianbr.github.io/makefiles`. They are designed to be human-readable for contributors and machine-friendly for tools like Copilot.

## Overview
- **Modular**: each library under `lib/` exposes its own `Makefile` plus optional helper `.mk` fragments.
- **Bootstrap-friendly**: the `fetch` script and local `make` targets automatically populate `.makefiles/` with the modules you need.
- **Consistent**: every makefile carries a `Last edited` header and includes the shared root logic so targets behave the same way across projects.

## Getting Started
1. Ensure you have GNU Make, `curl`, and any runtime the module requires (e.g., PHP for Composer) installed.
2. In your project, create a bootstrap rule that downloads missing modules:

```makefile
-include .makefiles/modules/composer/Makefile

.makefiles/modules/%:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

3. Run `make <target>` as usual; the first invocation pulls the requested module into `.makefiles/modules/`.

## Usage Examples
### Composer-focused Project
```makefile
-include .makefiles/modules/composer/Makefile

.PHONY: install clean

install::
	MAKEFILES_VERSION?=v1 make -C . install

clean::
	MAKEFILES_VERSION?=v1 make -C . clean

.makefiles/modules/%:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

### Multi-module (Composer + Docker)
```makefile
-include .makefiles/modules/composer/Makefile
-include .makefiles/modules/docker/Makefile

.PHONY: up down

up::
	make docker-up

down::
	make docker-down

.makefiles/modules/%:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

## Repository Layout
- `lib/` – source makefiles for every module.
- `.makefiles/` – generated cache inside consuming projects; mirrors the structure under `lib/`.
- `modules/` – example workspace used in tests (mirrors what consumers download).
- `fetch` – helper script that downloads the requested module/version over HTTPS.
- `CONTRIBUTIONS.md` – rules for adding or editing modules.

## Contributing
Please read [CONTRIBUTIONS.md](CONTRIBUTIONS.md) before opening a PR. It covers directory layout, header requirements, and how to structure module-specific targets so they compose cleanly.

## Support
If you spot a bug or have an idea for a new module, open an issue or start a discussion. When filing bugs, include the target you ran, the module(s) involved, and any console output so we can reproduce it quickly.
