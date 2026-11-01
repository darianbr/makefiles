# Examples

This folder contains standalone MVP examples for each module. Pick one folder, run `make <target>`, and adapt it into your own project.

## Modules

- [codeception](codeception): PHP Codeception tests + coverage
- [phpunit](phpunit): PHP PHPUnit tests + coverage
- [composer](composer): Composer install + clean
- [npm](npm): npm install + clean
- [rust](rust): Rust build, test, clippy, fmt + clean
- [typescript](typescript): TypeScript build + typecheck
- [vitest](vitest): Vitest test + coverage
- [stacked-tests](stacked-tests): Vitest + PHPUnit + Codeception in one project
- [docker](docker): Docker placeholder module wiring

## Common bootstrap pattern

Each example uses:

```makefile
.makefiles/modules/%/Makefile:
	curl -sf https://darianbr.github.io/makefiles/fetch | bash /dev/stdin $*
```

Generated `.makefiles/` and runtime outputs are intentionally gitignored inside each example.
