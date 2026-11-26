#!/usr/bin/env python3
"""Exercise cache recovery and updates using real curl and a local HTTP server."""
import functools
import http.server
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading

repo = Path(__file__).resolve().parent.parent


def run(args, cwd, env, expect=0):
    result = subprocess.run(args, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=30)
    if (result.returncode == 0) != (expect == 0):
        raise AssertionError(f"{args} exited {result.returncode}:\n{result.stdout}")
    return result.stdout


with tempfile.TemporaryDirectory(prefix="makefiles-http-") as temporary:
    root = Path(temporary)
    site = root / "site"
    site.mkdir()
    shutil.copytree(repo / "modules", site / "modules")
    shutil.copy(repo / "fetch", site / "fetch")
    project = root / "project"
    project.mkdir()
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(site))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    env = os.environ.copy()
    for key in ("MAKEFLAGS", "GNUMAKEFLAGS", "MF_LEGACY_GOALS", "MF_SCOPED_MODULE"):
        env.pop(key, None)
    env.update(MAKEFILES_BASE_URL=f"http://127.0.0.1:{server.server_port}/modules",
               MAKEFILES_FETCH_MAX_TIME="2", MAKEFILES_FETCH_CONNECT_TIMEOUT="1")
    try:
        run(["bash", str(repo / "fetch"), "wtree"], project, env)
        (project / "Makefile").write_text("include .makefiles/modules/wtree/Makefile\n")
        cached = project / ".makefiles/modules/wtree/targets.mk"
        original = (site / "modules/wtree/targets.mk").read_bytes()
        with cached.open("ab") as out:
            out.write(b"\nHTTP_DAMAGE=1\n")
        run(["make", "--no-print-directory", "wtree", "help"], project, env)
        assert cached.read_bytes() == original, "real HTTP recovery did not restore file"
        binary = project / "wtree-test"
        binary.write_text("#!/bin/sh\nexit 0\n")
        binary.chmod(0o755)
        env["WTREE_BIN"] = str(binary)
        marker = project / "stale-recipe-ran"
        # Create the aggregate verification stamp before corruption so this
        # checks reparsing after repair, not just first-run stamp creation.
        run(["make", "--no-print-directory", "-j4", "status"], project, env)
        with cached.open("a") as out:
            out.write("\nstatus::\n\t@touch stale-recipe-ran\n")
        run(["make", "--no-print-directory", "-j4", "status"], project, env)
        assert cached.read_bytes() == original, "aggregate recovery did not restore file"
        assert not marker.exists(), "aggregate build executed a stale corrupted recipe"
        (site / "modules/VERSION").write_text("0.3.0\n")
        output = run(["make", "--no-print-directory", "modules-update"], project, env)
        assert "0.2.0 -> 0.3.0" in output, output
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
    with cached.open("ab") as out:
        out.write(b"\nHTTP_DAMAGE=1\nstatus::\n\t@touch stale-recipe-ran\n")
    run(["make", "--no-print-directory", "status"], project, env, expect=1)
    assert not marker.exists(), "offline aggregate build executed a stale corrupted recipe"
    output = run(["make", "--no-print-directory", "wtree", "help"], project, env, expect=1)
    assert "wtree/targets.mk" in output, output
    output = run(["make", "--no-print-directory", "modules-update"], project, env, expect=1)
    assert "failed to update" in output, output

print("real HTTP recovery checks passed")
