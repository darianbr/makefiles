# wtree example

This example registers a local HTTPS route and serves the current directory
using Python's standard-library HTTP server on loopback. Run it in a Git
worktree. Install GNU Make, Bash, curl, tar, `uname`, `awk`, `mktemp`, standard
file utilities, `sha256sum` or `shasum`, Python 3, and a running container
engine. Go is not needed for a published binary. The intended wildcard DNS
record for `*.wtree.dev` resolves to `127.0.0.1`.

## Before starting

1. Obtain a currently valid, publicly trusted `*.wtree.dev` wildcard full
	chain and matching private key via the existing approved distribution
	channel. Put them at the following default paths, or set the file overrides:

	| Platform | `WTREE_CERT_FILE` default | `WTREE_KEY_FILE` default |
	|----------|---------------------------|--------------------------|
	| Linux | `${XDG_CONFIG_HOME:-$HOME/.config}/wtree/tls/fullchain.pem` | `${XDG_CONFIG_HOME:-$HOME/.config}/wtree/tls/privkey.pem` |
	| macOS | `$HOME/Library/Application Support/wtree/tls/fullchain.pem` | `$HOME/Library/Application Support/wtree/tls/privkey.pem` |

	`WTREE_CONFIG_DIR` changes the parent `wtree` directory and its default
	`tls/` paths; `WTREE_CERT_FILE` and `WTREE_KEY_FILE` override the individual
	files. Export these environment variables, or pass them to Make. Protect the
	private key and keep TLS files out of Git and images. The module does not
	download them; the CLI checks the pair, validity and wildcard name, but
	does not verify its chain against client trust roots.
2. Renewal is outside wtree: a designated trusted process uses Let's Encrypt
	DNS-01 and alone holds the restricted Porkbun credentials. Redistribute
	renewed files through the approved channel. wtree does not automatically
	reload them; file bind mounts may retain old inodes after replacement, so
	arrange a controlled container recreation and verify the served certificate.
3. On Linux, start Docker or Podman with host networking and make sure port 443
	is free. wtree prefers an existing compatible `wtree-caddy`, otherwise
	Podman then Docker; `WTREE_CONTAINER_ENGINE=docker` or `podman` selects an
	engine. If rootless Podman cannot bind 443 under the current host policy, an
	administrator may run the following once after reviewing its host-wide
	security impact:

	```sh
	sudo sysctl -w net.ipv4.ip_unprivileged_port_start=443
	```

	This permits unprivileged binding to ports 443 and above until reboot;
	persistent setup is an administrator's responsibility. Neither wtree nor
	`make start` runs it. On SELinux hosts, first check permissions and labels.
	`WTREE_SELINUX_RELABEL=1` is an explicit Podman opt-in that can recursively
	and persistently relabel the entire config directory and both TLS files,
	even on failed validation; review the CLI's SELinux documentation before
	using it. It is not enabled by default and Docker mounts are unchanged.
4. macOS is **not validated or claimed supported**. No real Mac test has been
	run. Docker Desktop 4.34+ with Settings > Resources > Network > Enable host
	networking enabled and applied is an intended prerequisite, not proof of
	safety. Docker Desktop's VM-based host networking cannot guarantee the
	intended loopback-only host boundary; do not rely on LAN isolation without
	real-host verification. Podman Machine is also unvalidated.

No Docker smoke test, publicly trusted certificate smoke test, or full port 443
smoke test has been run. The separate Linux rootless Podman integration test
uses high ports and a temporary self-signed certificate; it is not this
end-to-end example.

## Run and stop

Run `make start` to register port 8000 and start the foreground server. The CLI
prints the HTTPS URL. Override the port or branch-derived route with, for
example, `make start WTREE_PORT=3000 WTREE_SLUG=my-branch`. The port must not
already be in use; the CLI does not check upstream reachability. Ticket-bearing
branches use the first ticket key (for example `JIRA-12345` becomes
`jira-12345`); other branches are normalized. Supply a valid DNS-label slug
for detached HEAD or to avoid a collision. An already-active slug, including
one from the same worktree, causes `up` to fail without replacing it. Run
`make wtree status` to see routes, and use `make stop` before restarting or
choose a different slug.

In another terminal, run `make stop` with the same
`WTREE_SLUG` if one was supplied. Stop the foreground Python server with
Ctrl-C; `stop` only removes the route and does not supervise the server.
If the server exits unexpectedly, run `make stop` to remove the stale route.
If the worktree has multiple routes, select one with `WTREE_SLUG`; removing a
missing route is safe to repeat. The shared Caddy container remains running
after the last route is removed. `make wtree clean` leaves routes and container
unchanged.

## Bootstrap and version

The first module bootstrap fetches the shared Make files from the configured
published site; the wtree module must be published there before a fresh
consumer can fetch it. Version `0.1.0` is currently unreleased: local release
builds alone do not make downloads available. Publish `v0.1.0` with its
platform archives and `SHA256SUMS` at the default release directory,
`https://github.com/darianbr/worktree/releases/download/v0.1.0`, before using
automatic installation, or set `WTREE_VERSION` and `WTREE_RELEASE_URL` to an
actually published version and HTTPS release directory. Alternatively, set
`WTREE_BIN` to an existing non-symlink executable file. The default binary
cache is `.makefiles/tools/wtree-$(WTREE_VERSION)`.

The first `install`, `up`, `down` or `status` downloads and verifies the
matching archive if the executable is absent; the checksum comes from the same
release host and is not an independent signature. An existing executable is
reused without re-verification. `make wtree help` does not install the CLI once
module files are present, although the initial include can fetch the module.
See the [module documentation](../../README.md#worktree-proxy) for all Make
overrides. Do not commit the generated `.makefiles/` directory or TLS material.
