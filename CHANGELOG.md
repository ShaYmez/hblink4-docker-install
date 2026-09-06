# Changelog

All notable changes to the **HBlink4 Docker installer** (not upstream HBlink4) are documented here.

## 0.1.0 — 2026-09-06

- Initial release: one-shot Debian/Ubuntu installer for HBlink4 engine + official dashboard as two Compose v2 services on `network_mode: host`.
- Local image builds from https://github.com/n0mjs710/HBlink4 (`python:3.14-slim-bookworm`, 3.13 fallback for `dmr_utils3` wheels).
- Native Bash ANSI menu (no whiptail). Control scripts: start/stop/restart/flush/logs/update/upgrade/uninstall/diagnostics.
- Auto-download of Cortney’s JSON samples when host configs are missing; TCP event transport on 127.0.0.1:8765.
- Git update/upgrade of this installer and n0mjs710/HBlink4; configs are never overwritten on upgrade.
