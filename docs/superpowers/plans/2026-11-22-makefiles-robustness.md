# Makefiles Robustness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bound all fetch network calls, self-heal a corrupted local module cache automatically, and give consumers explicit version visibility + update.

**Architecture:** `fetch` records a `sha256sum -c`-compatible hash file (`.makefiles/modules/.manifest.sha256`) after every successful download. A new core include (`core/verify.mk`) verifies cached files lazily — for the selected module in scoped dispatch, for all imported modules in aggregate mode — and on mismatch re-runs fetch with `--force` once before failing. A `modules/VERSION` file (manifest-listed) plus `modules-version` / `modules-update` targets give explicit, non-silent version control.

**Tech Stack:** Bash 3.2-compatible shell, GNU Make 3.81-compatible makefiles, curl, coreutils (`sha256sum`/`shasum`).

**Spec:** `docs/superpowers/specs/2026-11-22-makefiles-robustness-design.md`

## Global Constraints

- `fetch` must keep working under Bash 3.2 with `set -u` (macOS): never expand a possibly-empty array bare — use the `${arr[@]+"${arr[@]}"}` pattern. Regression coverage: `tests/review-regressions.sh` with `FETCH_BASH`.
- All new Makefile constructs must work under GNU Make 3.81 (no `.SHELLFLAGS`, no Make-4-only features).
- Published-site layout is additive only; every published file must be listed in `modules/manifest.txt` (`make check-manifest` enforces this — run `make check` before committing).
- No silent auto-updates: re-fetching happens only on verified corruption or explicit `--force` / `modules-update`.
- Verification is local-only (no network) and must stay sub-second on the happy path.
- CI must stay green: `tests/wtree-dispatch.sh`, `tests/wtree-module.sh`, `tests/review-regressions.sh`, `make check` (ubuntu + macos).

## Review Focus

1. **Truncated cached file** (e.g. killed mid-download on a previous run) — next `make <module> <target>` must re-fetch and succeed without user action (Task 3, corruption test).
2. **Hash file deleted by the user** — treated as mismatch → one auto re-fetch, then normal operation (Task 3, missing-record test).
3. **Corruption + dead network** — the build must fail with an error naming the offending file(s), not hang and not loop (Task 3, offline-failure test; Task 1 timeout bounds the curl).
4. **Bash 3.2 + `set -u` in any new fetch code** — no unguarded empty-array expansion (Task 1/2, FETCH_BASH regression run).
5. **Consumer who fetched before this change** (no hash file yet) — first build self-heals via one re-fetch; subsequent builds are quiet (Task 3, legacy-cache test).

---

### Task 1: Bounded fetch with tunable timeouts

**Files:**
- Modify: `fetch` (all curl invocations + a timeout trap message)
- Modify: `modules/wtree/prerequisites.mk` (the two lazy-download curls)
- Test: `tests/fetch-timeouts.sh` (create)

**Interfaces:**
- Consumes: existing `fetch` staging design (unchanged).
- Produces: env vars `MAKEFILES_FETCH_MAX_TIME` (default `30`) and `MAKEFILES_FETCH_CONNECT_TIMEOUT` (default `10`), honored by every curl in `fetch` and in `modules/wtree/prerequisites.mk`. On a curl timeout the user sees `fetch: timed out downloading <file> (network?)` (or `[wtree] download timed out after <n>s (network?)`) instead of a bare curl exit code.

- [ ] **Step 1: Write the failing test** `tests/fetch-timeouts.sh`

Bash script, `set -euo pipefail`, style-matched to `tests/review-regressions.sh`:
- Start a local HTTP server that accepts connections but never responds (e.g. `nc -l` in a loop, or a tiny python `http.server` subclass that sleeps) on a random port; export `MAKEFILES_BASE_URL=http://127.0.0.1:<port>/modules`.
- Run `MAKEFILES_FETCH_MAX_TIME=1 MAKEFILES_FETCH_CONNECT_TIMEOUT=1 bash fetch wtree` in a temp dir; assert it exits non-zero within ~5s and stderr contains `timed out downloading`.
- Kill the server; clean up.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/fetch-timeouts.sh`
Expected: FAIL — fetch hangs (or the timeout message is absent).

- [ ] **Step 3: Implement** in `fetch`

Define `MAX_TIME="${MAKEFILES_FETCH_MAX_TIME:-30}"` and `CONNECT_TIMEOUT="${MAKEFILES_FETCH_CONNECT_TIMEOUT:-10}"` near the top; add `--max-time "$MAX_TIME" --connect-timeout "$CONNECT_TIMEOUT"` to every curl. Wrap the per-file download loop so a non-zero curl exit prints `fetch: timed out downloading $f (network?)` when the exit code is 28, else `fetch: failed downloading $f (curl exit $?)`, then exits non-zero (staging trap already cleans up). Apply the same flags + message to both curls in `modules/wtree/prerequisites.mk` (message prefix `[wtree]`).

- [ ] **Step 4: Run tests**

Run: `bash tests/fetch-timeouts.sh && bash tests/review-regressions.sh`
Expected: PASS. Also run `FETCH_BASH=/path/to/bash-3.2 bash tests/review-regressions.sh` when a Bash 3.2 build is available (CI macos covers it otherwise).

- [ ] **Step 5: Commit**

```bash
git add fetch modules/wtree/prerequisites.mk tests/fetch-timeouts.sh
git commit -m "Bound all fetch downloads with tunable timeouts (MAKEFILES_FETCH_*_TIMEOUT)"
```

---

### Task 2: Record a verifiable cache hash + VERSION file

**Files:**
- Modify: `fetch` (write `.manifest.sha256` after the move-in step)
- Create: `modules/VERSION` (content: `0.2.0`)
- Modify: `modules/manifest.txt` (add `VERSION` line, sorted position)
- Test: extend `tests/review-regressions.sh`

**Interfaces:**
- Consumes: fetch's staging dir + final `.makefiles/modules/` layout.
- Produces:
  - `.makefiles/modules/.manifest.sha256` — plain `sha256sum` output, one line per file, paths relative to `.makefiles/modules/`, covering **every** file under `.makefiles/modules/` except itself (so a second module's fetch extends the same record). `(cd .makefiles/modules && sha256sum -c --quiet .manifest.sha256)` must pass immediately after any successful fetch.
  - `modules/VERSION` at the repo root of the modules tree (served at `<site>/modules/VERSION`, manifest entry `VERSION`) — the module-set version, bumped by maintainers on any module change.

- [ ] **Step 1: Write the failing test** — extend `tests/review-regressions.sh` with a case: after a successful fetch of `wtree` into a temp consumer dir, assert `.makefiles/modules/.manifest.sha256` exists and `(cd .makefiles/modules && sha256sum -c --quiet .manifest.sha256)` exits 0; assert `.makefiles/modules/VERSION` exists and is non-empty.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/review-regressions.sh`
Expected: FAIL — hash file absent.

- [ ] **Step 3: Implement** in `fetch`

After the move-in loop (before the final echo), compute the record:
```sh
( cd "$DEST" && find . -type f ! -name '.manifest.sha256' -print \
    | sed 's#^\./##' | LC_ALL=C sort \
    | { command -v sha256sum >/dev/null 2>&1 && sha256sum -- "$@" || shasum -a 256 -- "$@"; } ) > "$DEST/.manifest.sha256"
```
(adapt to pass the sorted file list as arguments, guarding the empty case with the `${arr[@]+"${arr[@]}"}` pattern; `shasum -a 256` output format is `sha256sum`-compatible). Create `modules/VERSION` containing `0.2.0` and add `VERSION` to `modules/manifest.txt` in sorted order.

- [ ] **Step 4: Run tests**

Run: `bash tests/review-regressions.sh && make check`
Expected: PASS (`check-manifest` covers the new VERSION entry).

- [ ] **Step 5: Commit**

```bash
git add fetch modules/VERSION modules/manifest.txt tests/review-regressions.sh
git commit -m "Record a sha256sum-verifiable cache hash on fetch; publish modules/VERSION"
```

---

### Task 3: Lazy verification with one-shot self-heal

**Files:**
- Create: `modules/core/verify.mk`
- Modify: `modules/Makefile` (include verify.mk after dispatch.mk)
- Modify: `modules/core/dispatch.mk` (scoped gate runs module verification before the recursive make)
- Test: `tests/verify-cache.sh` (create)

**Interfaces:**
- Consumes: `.makefiles/modules/.manifest.sha256` (Task 2), `MF_MODULES`, `MF_MODULE_ENTRY_*` from registry.mk, `MAKEFILES_BASE_URL` default.
- Produces:
  - `.PHONY: mf-verify-all mf-verify-module`
  - `mf-verify-module` (takes `MF_VERIFY_MODULE=<name>`): verifies only that module's recorded lines; on mismatch or missing record → re-run fetch for that module with `--force` (via the published URL, same pattern as the consumer bootstrap rule) → verify once more → if still failing, stop with `makefiles: cache verification failed for <file(s)> in module '<name>'; re-fetch also failed`.
  - `mf-verify-all`: same over every imported module (`MF_MODULES`).
  - Happy path is a single local `sha256sum -c` pass (no network).
  - Hooks: scoped dispatch gate invokes `$(MAKE) --no-print-directory mf-verify-module MF_VERIFY_MODULE=$(MF_DISPATCH_MODULE)` before the recursive make; aggregate mode (exactly one goal, not inside a scoped recursive make — guard with `ifneq ($(MF_SCOPED_MODULE),)`) adds `mf-verify-all` as an extra prerequisite of the first goal using the same `$(goal)::` pattern dispatch.mk already uses.

- [ ] **Step 1: Write the failing test** `tests/verify-cache.sh`

Bash, `set -euo pipefail`, fixture consumer dir with the standard bootstrap (pattern rule + `-include .makefiles/modules/wtree/Makefile`), served from a local copy of the published tree (point `MAKEFILES_BASE_URL` at a `python3 -m http.server` rooted at the repo's `modules/` dir so no network is needed):
1. **corruption self-heal:** fetch wtree; append garbage to `.makefiles/modules/wtree/targets.mk`; run `make wtree help` → exits 0, and the file content matches the published copy again (re-fetched).
2. **missing record:** delete `.manifest.sha256`; run `make wtree help` → exits 0, hash file recreated.
3. **offline failure:** corrupt a file AND point `MAKEFILES_BASE_URL` at an unreachable port; run `make wtree help` → non-zero exit, stderr names the corrupted file, and it does not hang (wrap in a timeout).
4. **legacy cache:** fetch with a fetch version that writes no hash file (simulate by deleting the hash file after fetch), then run twice → first run re-fetches quietly, second run makes zero network calls (assert via server access log or by killing the server before the second run).

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/verify-cache.sh`
Expected: FAIL — corrupted file is served as-is.

- [ ] **Step 3: Implement** `modules/core/verify.mk` + hooks per the interface above. Keep all shell in one-line-per-command recipes (Make 3.81 per-line exit checking). The re-fetch call mirrors the consumer bootstrap: `curl -sf --max-time "${MAKEFILES_FETCH_MAX_TIME:-30}" "$BASE/fetch" | bash /dev/stdin <module> --force` where BASE is the site root derived from `MAKEFILES_BASE_URL` (strip the trailing `/modules`).

- [ ] **Step 4: Run tests**

Run: `bash tests/verify-cache.sh && bash tests/wtree-dispatch.sh && bash tests/wtree-module.sh && make check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/core/verify.mk modules/Makefile modules/core/dispatch.mk tests/verify-cache.sh
git commit -m "Verify cached module files lazily and self-heal corruption with one re-fetch"
```

---

### Task 4: Version visibility, explicit update, docs

**Files:**
- Modify: `modules/core/verify.mk` (add the two consumer targets) or a new `modules/core/version.mk` included from `modules/Makefile` — builder's call, prefer the smaller diff
- Modify: `modules/wtree/prerequisites.mk` (`mf-wtree-ensure` verifies its own module lines before invoking the binary)
- Modify: `CONTRIBUTIONS.md`, `README.md` (document `modules-version`, `modules-update`, the env vars from Task 1, and the self-heal behavior)
- Test: extend `tests/verify-cache.sh`

**Interfaces:**
- Consumes: `.makefiles/modules/VERSION`, `.manifest.sha256` (Task 2), verification logic (Task 3).
- Produces:
  - `make modules-version` — prints the recorded `VERSION` content plus the first 12 hex chars of the manifest hash; no network.
  - `make modules-update` — re-fetches every present module with `--force`, prints `<old> -> <new>` (VERSION before/after); explicit only, never a prerequisite of any other target.
  - `mf-wtree-ensure` runs the wtree-module hash check first (reusing Task 3's verify logic scoped to `wtree/*` lines) so direct `-f modules/wtree/Makefile` usage is also protected.

- [ ] **Step 1: Write the failing tests** — extend `tests/verify-cache.sh`:
  - `make modules-version` prints the published VERSION content and a 12-char hash; exits 0 offline.
  - Bump the local server's `VERSION` to `0.3.0`; `make modules-update` prints `0.2.0 -> 0.3.0`; `make modules-version` now prints `0.3.0`.
  - A normal `make wtree help` does NOT re-fetch when the site VERSION is newer (assert no new server access for module files) — updates stay explicit.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/verify-cache.sh`
Expected: FAIL — unknown target `modules-version`.

- [ ] **Step 3: Implement** the two targets + the `mf-wtree-ensure` check + docs. In CONTRIBUTIONS.md add a short "Cache verification and updates" section (style-matched to the existing Pre-PR Checklist section): what is verified, when, the one-retry self-heal, the env vars, and that updates are explicit by design.

- [ ] **Step 4: Run full suite**

Run: `bash tests/verify-cache.sh && bash tests/fetch-timeouts.sh && bash tests/review-regressions.sh && bash tests/wtree-dispatch.sh && bash tests/wtree-module.sh && make check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/core/ modules/wtree/prerequisites.mk CONTRIBUTIONS.md README.md tests/verify-cache.sh
git commit -m "Add modules-version and explicit modules-update; document cache self-heal"
```
