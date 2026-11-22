# Makefiles Robustness Design

Date: 2026-11-22
Status: proposed (pending approval)

## Intent and why

The Makefiles system (fetch script + published modules + lazy binary bootstrap)
is the onboarding path for wtree and every other module. It already embodies
the design philosophy in its bones — staged downloads, manifest validation
before touching the cache, atomic moves, checksum-verified lazy installs,
idempotent "already present" skips. Three gaps remain:

1. **Unbounded network.** `fetch`'s curl calls have no `--max-time`; a stalled
   network hangs the build forever (violates "bounded, no hangs").
2. **Corrupted cache is never detected.** The "already present" fast path is
   `test -f .makefiles/modules/<module>/Makefile`. A truncated or half-written
   file passes that test and is served to the user, who then debugs broken
   Makefiles by hand (violates "self-heal, don't surface" and "fix cheaper than
   break").
3. **No version awareness.** Consumers cannot tell which module set they have;
   the only update path is a manual `--force` re-fetch with no visibility into
   what changed.

User requirements: explicit updates only (no silent auto-updates of build
tooling); everything else should be invisible and self-mending.

## Goals

- G1: No fetch operation can hang indefinitely; every network call has a
  deadline, and failure leaves the cache intact (already true) with a clear
  error.
- G2: A corrupted or incomplete local cache is detected automatically and
  repaired by re-fetching — the user never debugs broken module files.
- G3: Consumers can see which version of the module set they have, and update
  explicitly via a single target.

## Non-goals

- No silent auto-updates on build (explicit only — user decision).
- No change to the published-site layout or manifest format (additive only).
- No new runtime dependencies beyond coreutils + curl (already required).
- No changes to module Makefile conventions.

## Anti-goals

- Any failure mode whose repair requires the user to hand-edit or delete cache
  files.
- A build that can block on the network for more than a bounded time.

## Constraints

- `fetch` must keep working under Bash 3.2 (macOS) with `set -u` — the
  `${files[@]+"${files[@]}"}` pattern and friends are load-bearing; regression
  coverage exists in `tests/review-regressions.sh` (FETCH_BASH).
- GNU Make 3.81 compatibility for any new Makefile targets.
- The published site is GitHub Pages from `main`; anything fetched must be
  listed in `modules/manifest.txt` (enforced by `make check-manifest`, PR #15).
- CI: `tests/wtree-dispatch.sh`, `tests/wtree-module.sh`,
  `tests/review-regressions.sh`, and the `check` workflow must stay green on
  ubuntu + macos.

## Approaches considered

**A — Hash-pinned cache with explicit update (chosen).** Record a manifest hash
at fetch time; verify it on every use; mismatch → auto re-fetch (self-heal).
Version visibility comes from the recorded hash + a `modules-update` target.

**B — Timestamp/ETag freshness checks.** Rejected: requires state about the
remote, adds network calls to the hot path, and does not detect local
corruption (only staleness).

**C — Status quo + better error messages.** Rejected: leaves the user debugging
broken files; violates G2.

## Design

### D1 — Bounded fetch

- Add `--max-time 30 --connect-timeout 10` to every curl in `fetch` (and to the
  lazy binary download in `modules/wtree/prerequisites.mk`, which currently has
  no timeout either).
- Tunability (builder's call, resolving review question): both values are
  overridable via environment — `MAKEFILES_FETCH_MAX_TIME` and
  `MAKEFILES_FETCH_CONNECT_TIMEOUT` (seconds) — defaulting to 30/10. This
  covers slow CI egress and proxied local networks without adding Makefile
  surface; document them in CONTRIBUTIONS.md.
- On timeout, curl's non-zero exit already aborts under `set -e`; add a trap
  message so the user sees `fetch: timed out downloading <file> (network?)`
  instead of a bare curl code. Staging semantics unchanged: cache stays intact.

### D2 — Self-healing cache verification

- After a successful fetch, write `.makefiles/modules/.manifest.sha256`:
  SHA-256 of the fetched `manifest.txt` plus per-file hashes of every file in
  the module set. Format (builder's call, resolving review question): plain
  `sha256sum` output — one line per file, paths relative to
  `.makefiles/modules/`, so `sha256sum -c .manifest.sha256` works verbatim.
  No custom header; `manifest.txt` and `VERSION` are ordinary lines because
  they are part of the fetched set.
- Verification location (builder's call, resolving review question): in the
  core dispatch path (`core/dispatch.mk`) — when a module target is dispatched,
  run a hash check for that module first. This gives every module verification
  for free via core, runs lazily (only when a module is actually used), and
  leaves builds that don't use fetch untouched. The wtree module's
  `mf-wtree-ensure` gets the same check before invoking the binary.
- Retry semantics (builder's call, resolving review question): automatic,
  within the same build. On mismatch or missing record, re-run fetch for that
  module with `--force` (whole module set — the staging design already makes
  this safe and cheap), then verify once more. One retry total; if the second
  verification fails, stop the build with an error naming the offending file(s)
  plus the underlying fetch error.
- Verification is local-only (no network) and sub-second for a small module
  set, so it stays invisible on the happy path.
- `--force` remains the manual escape hatch; the recorded hash file is updated
  on every successful fetch.
- Scope (builder's call, resolving review question): the wtree *binary* is out
  of scope for `.manifest.sha256`. It already has its own SHA256SUMS
  verification at install time and is placed by an atomic move that nothing
  modifies afterward; re-verifying it on every use would be redundant. D1 adds
  only timeouts to `prerequisites.mk`.

### D3 — Version visibility + explicit update

- Add a `VERSION` file at the site root listing the current module-set version
  (bumped by maintainers on any module change). It is listed in
  `modules/manifest.txt`, so `check-manifest` covers it, fetch downloads it as
  an ordinary file, and D2's `.manifest.sha256` verifies it like any other
  line — no separate tracking (builder's call, resolving review question).
  It is required, not optional: a missing VERSION in the manifest is a
  manifest error caught by `check-manifest`, so consumers can always rely on
  it being present after a successful fetch.
- `.manifest.sha256` doubles as the version record: `make modules-version`
  prints the recorded `VERSION` content plus the manifest hash (short form) so
  two machines can be compared at a glance.
- New consumer target `modules-update`: re-fetches all present modules with
  `--force`, prints old → new version. Explicit only; never runs as part of a
  normal build.

## What is left to the builder

- Exact placement of the verification hook (core Makefile vs per-module) —
  prefer core so every module gets it for free; keep it out of the hot path of
  modules that don't use fetch.
- Hash file format details (must be parseable by `sha256sum -c` where possible).
- Test additions: corrupted-file self-heal test, timeout behavior test (mock
  slow server or `--max-time 1`), Bash 3.2 regression coverage for any new
  array usage.
