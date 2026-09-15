# Lademonitor – Home Assistant Add-on

**Language:** English | [Deutsch](README.md)

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](LICENSE)

Home Assistant Supervisor add-on repository for
[Lademonitor-Server](https://github.com/iDomi94/Lademonitor-Server)
(a self-hosted charging session tracking app for an EV). Runs directly
inside Home Assistant OS/Supervised, as an alternative to the previous
Unraid single-container deployment – the same container approach (backend +
Postgres in one image), just with Supervisor conventions (`/data` path,
Ingress) instead of a manual `docker run`.

## Installation

1. **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Enter this repo's URL: `https://github.com/iDomi94/Lademonitor-HA-Addon`
3. Install "Lademonitor", then start it
4. The web UI is reachable via the sidebar entry (Ingress) or directly via
   `http://<home-assistant-ip>:8111`
5. Register the first account (`/register`) – it automatically becomes
   admin; see the main repo for the further steps (creating a vehicle, etc.)

> **Companion project:** [Lademonitor-HA](https://github.com/iDomi94/Lademonitor-HA)
> (HACS integration) pulls statistics sensors (cost/consumption/km) directly
> into HA and replaces the previous `rest_command` call with a manual
> bearer token with a regular service
> (`lademonitor.push_charging_session`) – its README contains a
> complete example automation. If the server runs as this add-on on the
> same HA instance, simply enter `http://localhost:8000`
> (internal add-on port) or the HA IP with port `8111` as the server URL.

## Network access (local vs. external)

Both Ingress access (sidebar button) and the direct port `8111` only work
within your Home Assistant server's local network – neither path makes the
app reachable from outside automatically.

- **Ingress** is also not a substitute for real API access: the sidebar
  URL is tied to a logged-in HA browser session (token per session) and is
  therefore not usable for standalone API clients such as the
  [iOS app](https://github.com/iDomi94/Lademonitor-App) – the app always
  has to talk to the direct port.
- For access on the go (e.g. the iOS app outside the home network) there
  are two options:
  1. **VPN into the home network** (e.g. WireGuard) – the simplest and
     recommended solution, no additional public port needed.
  2. **Your own reverse proxy/Nginx vhost** (own subdomain with TLS)
     pointing to `http://<home-assistant-ip>:8111` – analogous to the
     previous Unraid+Nginx setup. If you already expose Home Assistant
     itself via Nginx, that is **not** sufficient for this: that proxy
     typically only points to HA's own port (8123, including the Ingress
     paths running over it), not to 8111 – a separate, additional
     server/location block is needed for that.
  3. When exposed publicly, be sure to follow the security note in the
     [server repo](https://github.com/iDomi94/Lademonitor-Server#sicherheitshinweis)
     (among other things, no rate limiting on login/registration).

## Data & backup

All data (the entire Postgres database) lives under the Supervisor-managed
`/data` path of the add-on and is therefore part of regular HA
backups/snapshots. In addition, the built-in export/import (Settings →
Data backup in the web UI) remains available for portable CSV backups.

## Structure of this repo

```
repository.yaml       - Add-on repository metadata for Supervisor
.github/workflows/
  check-server-release.yml - periodically checks for new Lademonitor-Server
                              releases, updates submodule + version, tags
  build.yml                 - on every v*.*.* tag, builds the multi-arch
                              image and publishes it to GHCR
lademonitor/
  config.yaml           - Add-on configuration (image, ports, Ingress, options)
  build.yaml              - Base image per architecture (local builds/CI only)
  Dockerfile                - Builds backend + Postgres into one image
  run.sh                      - Entrypoint: starts Postgres + uvicorn
  server/                      - Git submodule -> Lademonitor-Server
                              (provides backend/app + requirements.txt)
```

**As with [Wealth Dashboard](https://github.com/halvar20000/wealth-dashboard)**,
Supervisor no longer builds anything on the Home Assistant host itself:
`config.yaml` references a ready-built multi-arch image from GHCR under
`image:` (`ghcr.io/idomi94/lademonitor-addon`), and Supervisor just pulls the
tag matching `version`.

`server/` remains a Git submodule, not copied code, to avoid source drift
between the server and add-on repos – but it is no longer kept up to date by
hand:

1. `check-server-release.yml` runs every 6 hours (and manually via
   "Run workflow") and checks the latest `v*.*.*` release of
   `Lademonitor-Server`.
2. On a new version, it points the submodule at exactly that tag, bumps
   `version` in `lademonitor/config.yaml` to match, and pushes a
   corresponding Git tag (e.g. `v0.19.0`).
3. That tag triggers `build.yml`: a multi-arch build (amd64/aarch64) pushed
   to `ghcr.io/idomi94/lademonitor-addon:<version>` (+ `:latest`).
4. Supervisor then shows an update on every installation – add-on and
   server version stay identical, with no manual submodule bump.

One-time setup for the workflows to work: under **Settings → Actions →
General → Workflow permissions**, enable "Read and write permissions" (needed
for the Git tag push and the GHCR push using the default `GITHUB_TOKEN`),
and make the resulting GHCR package "Public" once so Supervisor can pull it
without logging in.

## Building/testing locally

```bash
cd lademonitor
docker build --build-arg BUILD_FROM=postgres:16 -t lademonitor-addon-test .
docker run --rm -p 8111:8000 -v "$(pwd)/testdata:/data" lademonitor-addon-test
```

A full Supervisor test (Ingress, snapshots, multi-arch build) is only
possible on real Home Assistant OS hardware.
