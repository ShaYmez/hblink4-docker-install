# HBlink4 Docker Installer

Debian 11 / 12 / 13 and Ubuntu 22.04 / 24.04 LTS.

This is a **destructive** one-shot installer for [HBlink4](https://github.com/n0mjs710/HBlink4) (Cortney T. Buffington, N0MJS) as two Docker Compose v2 services on `network_mode: host`. Recommended on a freshly installed machine.

HBlink4 is **not** on Docker Hub. This installer clones Cortney’s git tree to `/opt/HBlink4` and **builds local images** (`hblink4-engine:local` and `hblink4-dash:local`) from `python:3.14-slim-bookworm`. If `dmr_utils3` / `bitarray` has no usable 3.14 wheel, the build retries on `python:3.13-slim-bookworm`.

**This repository is the installer only.** HBlink4 and its companion programs remain copyright Cortney T. Buffington, N0MJS. The installer is copyright Shane Daley, M0VUB aka ShaYmez.

## Stack

- **hblink4** — DMR engine, UDP **62031** (host network)
- **hblink4-dash** — official FastAPI dashboard, TCP **8080**
- Event link: TCP **127.0.0.1:8765** (dashboard listens, engine dials). Official samples use a Unix socket; the installer patches both JSON files so split containers work.

The dashboard is a **separate Compose service** so it can be swapped later (for example an HBMon-style monitor) without touching the engine.

## Prerequisite

Root on Debian 11/12/13 or Ubuntu 22.04/24.04. Git installed. Docker Compose **v2** (`docker compose` with a space) is installed by this script from Docker’s official repo.

```sh
apt-get install -y git
apt update
sudo su
```

## Installation

```sh
git clone https://github.com/ShaYmez/hblink4-docker-install
cd hblink4-docker-install
./hblink4-docker-install.sh
```

Clone wherever you like; `/opt` is a good home. Follow the prompts. Change `passphrase` in `/etc/hblink4/config/config.json` from `CHANGE-ME` before putting a live repeater on the server.

Control menu:

```sh
hblink4-menu
```

Standalone commands:

```sh
hblink4-start
hblink4-stop
hblink4-restart
hblink4-flush
hblink4-logs          # docker compose logs -f --tail=50
hblink4-diagnostics
hblink4-update
hblink4-upgrade
hblink4-uninstall
```

## Configuration

If `config.json` is missing, the installer downloads Cortney’s raw `config_sample.json` (and the dashboard sample) from GitHub so the containers can start. Existing operator files are **never** overwritten.

| Host path | Role |
|-----------|------|
| `/etc/hblink4/config/config.json` | Engine |
| `/etc/hblink4/dashboard/config.json` | Dashboard |
| `/etc/hblink4/dashboard/data/` | RadioID cache / last-heard |
| `/var/log/hblink4/` | Engine file logs |
| `/opt/HBlink4` | Cortney’s git checkout (build context) |
| `/etc/hblink4/docker-compose.yml` | Compose v2, no `version:` key |

```sh
cd /etc/hblink4
docker compose up -d
docker compose down
docker compose logs -f --tail=50
nano config/config.json
```

## Update and upgrade

Both pull **this** installer repo and **n0mjs710/HBlink4**, then rebuild local images. Configs are not touched.

```sh
hblink4-update      # git pull + docker compose build + up
hblink4-upgrade     # same, with --no-cache --pull of the Python base image
```

There is no `docker compose pull` of an HBlink4 app image — it does not exist on Hub.

## Ports

```
dashboard  8080/tcp
events     8765/tcp   (localhost only)
MMDVM      62031/udp
IPv6 DMR   62032/udp  (off by default)
OBP        per openbridge_connections local_port in config.json
ssh        22/tcp
```

## Companion programs (not installed)

These are **separate daemons** by N0MJS. They are not plugins inside HBlink4 and this installer does not build or start them. With host networking they can reach `127.0.0.1:62031` from the same machine.

| Program | Repo | How it talks to HBlink4 |
|---------|------|-------------------------|
| dmr-talkback | https://github.com/n0mjs710/dmr-talkback | Logs in as an HBP repeater (voice test / echo). Needs an access-control entry; subscribes with `Options=`. |
| ipsc2hbpc | https://github.com/n0mjs710/ipsc2hbpc | Motorola IPSC ⇄ HBP (C, preferred). Looks like a repeater to HBlink4. |
| ipsc2hbp | https://github.com/n0mjs710/ipsc2hbp | Same translator in Python 3.11+. Prefer ipsc2hbpc for production. |
| cc2obp | https://github.com/n0mjs710/cc2obp | c-Bridge CC-CC ⇄ OpenBridge. Peer it to `openbridge_connections` in `config.json`. |

OpenBridge trunks themselves are **built into** HBlink4 (`openbridge_connections` in the engine JSON). Typical use is an HBlink3 core to this HBlink4 edge — no extra binary.

## Uninstall

```sh
hblink4-uninstall
```

Backs up `/etc/hblink4` under `/root/hblink4-backup-<timestamp>`. Docker packages stay installed.

## License and credits

- **HBlink4** and companions: Copyright (C) 2016-2025 Cortney T. Buffington, N0MJS `<n0mjs@me.com>` — GNU GPLv3
- **This installer** (scripts, Compose, Dockerfiles, menu): Copyright (C) 2026 Shane Daley, M0VUB aka ShaYmez `<shane@freestar.network>` — GNU GPLv3

This project installs and containers HBlink4. It does not claim copyright in HBlink4 or the companion programs.

More: https://freestar.network/development and https://github.com/ShaYmez/
