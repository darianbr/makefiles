# Stacked test modules example

This example demonstrates module stacking with three test runners in one project:

- `vitest` (JavaScript/TypeScript)
- `phpunit` (PHP)
- `codeception` (PHP)

It imports five modules in one Makefile:

- `npm` for Node dependencies
- `composer` for PHP dependencies
- `vitest` for JS/TS tests
- `phpunit` for PHPUnit tests
- `codeception` for Codeception tests

## Why this shows stacking

Aggregate targets run across all imported modules that provide a target.

- `make install` runs both npm and composer installs.
- `make test` runs vitest, phpunit, and codeception tests.
- `make coverage` runs coverage for vitest, phpunit, and codeception.

Scoped targets let you run one runner at a time:

- `make vitest test`
- `make phpunit test`
- `make codeception test`

## Quick start

```bash
make install
make test
```

Optional coverage:

```bash
make coverage
```

The helper aliases `make test-stack` and `make coverage-stack` run install first, then the aggregate test or coverage target.
