#!/usr/bin/env python3
"""Regressions for concurrent and interrupted cache publication."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

repo = Path(__file__).resolve().parent.parent
errors = []
with tempfile.TemporaryDirectory(prefix="makefiles-publication-") as temp:
    root = Path(temp)
    remote = root / "remote" / "modules"
    shutil.copytree(repo / "modules", remote)
    project = root / "project"
    project.mkdir()
    binary = root / "bin"
    binary.mkdir()
    wrapper = binary / "mv"
    wrapper.write_text('''#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    .makefiles/modules)
      if [ "${PUBLISH_MODE:-}" = fail ]; then exit 75; fi
      ;;
  esac
done
exec "$REAL_MV" "$@"
''')
    wrapper.chmod(0o755)
    env = os.environ.copy()
    env.update(MAKEFILES_BASE_URL=remote.as_uri(), REAL_MV=shutil.which("mv"),
               PATH=str(binary) + os.pathsep + env["PATH"])

    def fetch(module, *, mode="", writer="", force=False):
        args = [os.environ.get("FETCH_BASH", "bash"), str(repo / "fetch"), module]
        if force:
            args.append("--force")
        return subprocess.Popen(args, cwd=project, env=dict(env, PUBLISH_MODE=mode, WRITER=writer),
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    def finish(process):
        try:
            out, _ = process.communicate(timeout=40)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            raise AssertionError("fetch publication timed out")
        return process.returncode, out

    status, output = finish(fetch("wtree"))
    assert status == 0, output
    one = fetch("phpunit", mode="barrier", writer="one")
    two = fetch("rust", mode="barrier", writer="two")
    for process in (one, two):
        status, output = finish(process)
        assert status == 0, output
    record = (project / ".makefiles/modules/.manifest.sha256").read_text()
    for module in ("wtree", "phpunit", "rust"):
        if not any(line.endswith("  " + module + "/Makefile") for line in record.splitlines()):
            dirs = sorted(p.name for p in (project / ".makefiles/modules").iterdir() if p.is_dir())
            errors.append("concurrent fetches lost the " + module + " checksum; dirs=" + repr(dirs) + "\nrecord=" + record)

    # Force a different root file into the remote, then fail after its publish
    # but before the remaining files or checksum record have been replaced.
    cache = project / ".makefiles/modules"
    previous = (cache / "Makefile").read_bytes()
    (remote / "Makefile").write_bytes(previous + b"\n# newer publication\n")
    status, output = finish(fetch("wtree", mode="fail", force=True))
    assert status != 0, "injected publication failure unexpectedly succeeded"
    if (cache / "Makefile").read_bytes() != previous:
        errors.append("interrupted publication left partially replaced cache files")

    # Simulate a crash after moving a legacy cache directory but before
    # recreating the modules symlink. The next fetch must recover automatically.
    cache.unlink(missing_ok=True)
    legacy = root / "project/.makefiles/.modules-generations/legacy"
    legacy.mkdir()
    (legacy / "Makefile").write_text("legacy\n")
    status, output = finish(fetch("wtree", force=True))
    assert status == 0, output
    assert (cache / "Makefile").is_file()

if errors:
    raise SystemExit("FAIL: " + "; ".join(errors))
print("fetch publication checks passed")
