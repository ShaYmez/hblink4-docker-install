# Changelog

All notable changes to the **HBlink4 Docker installer** (not upstream HBlink4) are documented here.

## 0.2.0 — 2026-09-06

- Optional HTTPS: `hblink4-ssl <fqdn> <email>` installs Apache + certbot on demand, terminates TLS on 443, proxies `/` and `/ws` to uvicorn on `127.0.0.1:8080`, then binds the dashboard to localhost. HTTP on 80 redirects to HTTPS. `--dry-run` supported. Menu: Configuration → Enable HTTPS.
- Fix `hblink4-menu` / `hblink4-initial-setup`: `$(read_choice)` captured the `Select:` prompt, so typed numbers never matched.
- Align banner, status, menus, footer, and installer section rules to one 65-column light box.
- Bug pass: `hblink4-update` re-execs after git pull (same as upgrade); `.env` Python pin is kept across compose-tree copies; `host_ip` uses the routing table; flush no longer restarts the Docker daemon; menu reboot/shutdown/re-install require `yes`.
- Production hardening: dashboard HTTP healthcheck so the engine waits for `service_healthy`; backup `docker-compose.yml` before update overwrite; merge `userland-proxy` into `/etc/docker/daemon.json` instead of replacing the file.

## 0.1.0 — 2026-09-06

- Initial release: one-shot Debian/Ubuntu installer for HBlink4 engine + official dashboard as two Compose v2 services on `network_mode: host`.
- Local image builds from https://github.com/n0mjs710/HBlink4 (`python:3.14-slim-bookworm`, 3.13 fallback for `dmr_utils3` wheels).
- Native Bash ANSI menu (no whiptail). Control scripts: start/stop/restart/flush/logs/update/upgrade/uninstall/diagnostics.
- Auto-download of Cortney’s JSON samples when host configs are missing; TCP event transport on 127.0.0.1:8765.
- Git update/upgrade of this installer and n0mjs710/HBlink4; configs are never overwritten on upgrade.
