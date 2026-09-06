#!/bin/bash
# HBlink4 Docker installer — shared library
# Version 0.1.0 (06092026)
#
#   Copyright (C) 2026 Shane Daley, M0VUB aka ShaYmez. <shane@freestar.network>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or
#   (at your option) any later version.
#
# HBlink4 (the DMR server) is Copyright (C) 2016-2025 Cortney T. Buffington, N0MJS.

# Prevent double-source
if [ -n "${HBLINK4_COMMON_LOADED:-}" ]; then
	return 0 2>/dev/null || true
fi
HBLINK4_COMMON_LOADED=1

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HBDIR="${HBDIR:-/etc/hblink4}"
HBLINK4_SRC="${HBLINK4_SRC:-/opt/HBlink4}"
HBLINK4_LOGDIR="${HBLINK4_LOGDIR:-/var/log/hblink4}"
RADIO_UID="${RADIO_UID:-54000}"
HBLINK4_REPO="${HBLINK4_REPO:-https://github.com/n0mjs710/HBlink4.git}"
SAMPLE_ENGINE_URL="${SAMPLE_ENGINE_URL:-https://raw.githubusercontent.com/n0mjs710/HBlink4/main/config/config_sample.json}"
SAMPLE_DASH_URL="${SAMPLE_DASH_URL:-https://raw.githubusercontent.com/n0mjs710/HBlink4/main/dashboard/config_sample.json}"
PYTHON_IMAGE_DEFAULT="${PYTHON_IMAGE_DEFAULT:-python:3.14-slim-bookworm}"
PYTHON_IMAGE_FALLBACK="${PYTHON_IMAGE_FALLBACK:-python:3.13-slim-bookworm}"

installer_path() {
	if [ -f "${HBDIR}/.installer_path" ]; then
		cat "${HBDIR}/.installer_path"
		return
	fi
	echo "/opt/hblink4-docker-install"
}

# ---------------------------------------------------------------------------
# ANSI colours (no figlet, no whiptail, no gum)
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
	C_RESET=$'\033[0m'
	C_BOLD=$'\033[1m'
	C_DIM=$'\033[2m'
	C_RED=$'\033[31m'
	C_GREEN=$'\033[32m'
	C_YELLOW=$'\033[33m'
	C_BLUE=$'\033[34m'
	C_MAGENTA=$'\033[35m'
	C_CYAN=$'\033[36m'
	C_WHITE=$'\033[37m'
	C_BRED=$'\033[91m'
	C_BGREEN=$'\033[92m'
	C_BYELLOW=$'\033[93m'
	C_BCYAN=$'\033[96m'
	C_BWHITE=$'\033[97m'
else
	C_RESET= C_BOLD= C_DIM= C_RED= C_GREEN= C_YELLOW= C_BLUE=
	C_MAGENTA= C_CYAN= C_WHITE= C_BRED= C_BGREEN= C_BYELLOW=
	C_BCYAN= C_BWHITE=
fi

ok()   { echo "${C_GREEN}✓${C_RESET} $*"; }
warn() { echo "${C_YELLOW}⚠${C_RESET} $*"; }
err()  { echo "${C_RED}✗${C_RESET} $*" >&2; }
note() { echo "${C_CYAN}▸${C_RESET} $*"; }

require_root() {
	if [ "${EUID:-$(id -u)}" -ne 0 ]; then
		err "You must be root to run this script."
		exit 1
	fi
}

host_ip() {
	ip -4 a 2>/dev/null | awk '/inet / && /eth0|ens|enp|eno/ {split($2,a,"/"); print a[1]; exit}'
}

container_running() {
	docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null | grep -qx true
}

compose_in_hbdir() {
	if [ ! -f "${HBDIR}/docker-compose.yml" ]; then
		err "docker-compose.yml not found in ${HBDIR}"
		return 1
	fi
	( cd "$HBDIR" && docker compose "$@" )
}

print_banner() {
	local ver
	ver="$(cat "$(installer_path)/VERSION" 2>/dev/null || echo "0.1.0")"
	echo "${C_BCYAN}"
	cat << 'EOF'
  ┌─────────────────────────────────────────────────────────────┐
  │                                                             │
  │     ██╗  ██╗██████╗ ██╗     ██╗███╗   ██╗██╗  ██╗██╗  ██╗   │
  │     ██║  ██║██╔══██╗██║     ██║████╗  ██║██║ ██╔╝██║  ██║   │
  │     ███████║██████╔╝██║     ██║██╔██╗ ██║█████╔╝ ███████║   │
  │     ██╔══██║██╔══██╗██║     ██║██║╚██╗██║██╔═██╗ ╚════██║   │
  │     ██║  ██║██████╔╝███████╗██║██║ ╚████║██║  ██╗     ██║   │
  │     ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝     ╚═╝   │
  │                                                             │
EOF
	echo "  │     ${C_BWHITE}Docker Installer  v${ver}${C_BCYAN}                               │"
	echo "  │     ${C_DIM}Aka ShaYmez${C_BCYAN}  ·  engine + dashboard  ·  host net      │"
	echo "  └─────────────────────────────────────────────────────────────┘"
	echo "${C_RESET}"
}

print_status_box() {
	local eng="stopped" dash="stopped" ip
	ip="$(host_ip)"
	[ -z "$ip" ] && ip="unknown"
	container_running hblink4 && eng="${C_BGREEN}running${C_RESET}" || eng="${C_BRED}stopped${C_RESET}"
	container_running hblink4-dash && dash="${C_BGREEN}running${C_RESET}" || dash="${C_BRED}stopped${C_RESET}"
	echo "${C_CYAN}  ┌─────────────────────────────────────────────────────────────┐${C_RESET}"
	printf "  ${C_CYAN}│${C_RESET}  Host %-18s  Engine %-18s          ${C_CYAN}│${C_RESET}\n" "$ip" "$eng"
	printf "  ${C_CYAN}│${C_RESET}  Dash  %-40s          ${C_CYAN}│${C_RESET}\n" "$dash"
	echo "${C_CYAN}  └─────────────────────────────────────────────────────────────┘${C_RESET}"
}

print_menu_box() {
	# Args: title, then N lines of "key|label"
	local title="$1"
	shift
	echo
	echo "${C_CYAN}  ╔═══════════════════════════════════════════════════════════════╗${C_RESET}"
	printf "  ${C_CYAN}║${C_RESET}  ${C_BOLD}%-61s${C_RESET}${C_CYAN}║${C_RESET}\n" "$title"
	echo "${C_CYAN}  ╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
	local line key label
	for line in "$@"; do
		key="${line%%|*}"
		label="${line#*|}"
		printf "  ${C_CYAN}║${C_RESET}    ${C_BYELLOW}[%s]${C_RESET}  %-54s ${C_CYAN}║${C_RESET}\n" "$key" "$label"
	done
	echo "${C_CYAN}  ╚═══════════════════════════════════════════════════════════════╝${C_RESET}"
	echo
}

pause() {
	echo
	read -r -p "  Press Enter to continue..." _
}

confirm_yes() {
	local prompt="${1:-Continue? (yes/no): }"
	local answer
	read -r -p "$prompt" answer
	[ "$answer" = "yes" ]
}

dots() {
	echo "."
	sleep 0.3
	echo ".."
	sleep 0.3
	echo "..."
}

print_footer() {
	local ip
	ip="$(host_ip)"
	echo
	echo "${C_CYAN}*************************************************************************${C_RESET}"
	echo
	echo "              HBlink4 is Copyright (C) Cortney T. Buffington, N0MJS"
	echo "              This installer: Copyright © 2026 Shane Daley - M0VUB"
	echo "                              Aka ShaYmez  <shane@freestar.network>"
	echo
	echo "                     Your IP address is ${ip:-unknown}"
	echo "                    Type 'hblink4-menu' for main menu"
	echo
	echo "${C_CYAN}*************************************************************************${C_RESET}"
}

# ---------------------------------------------------------------------------
# JSON sample fetch + TCP event-transport patch
# ---------------------------------------------------------------------------
_download_sample() {
	local url="$1" dest="$2" fallback="$3"
	if command -v curl >/dev/null 2>&1; then
		if curl -fsSL --connect-timeout 15 "$url" -o "$dest"; then
			return 0
		fi
	elif command -v wget >/dev/null 2>&1; then
		if wget -q -O "$dest" "$url"; then
			return 0
		fi
	fi
	if [ -n "$fallback" ] && [ -f "$fallback" ]; then
		cp -f "$fallback" "$dest"
		return 0
	fi
	return 1
}

# Patch a JSON file in place: engine|dash
patch_tcp_events() {
	local path="$1" kind="$2"
	python3 - "$path" "$kind" << 'PY'
import json, sys
path, kind = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    cfg = json.load(f)
if kind == "engine":
    d = cfg.setdefault("dashboard", {})
    d["enabled"] = True
    d["transport"] = "tcp"
    d["host_ipv4"] = "127.0.0.1"
    d["port"] = 8765
    d["disable_ipv6"] = True
else:
    er = cfg.setdefault("event_receiver", {})
    er["transport"] = "tcp"
    er["bind_ipv4"] = "127.0.0.1"
    er["port"] = 8765
    er["disable_ipv6"] = True
with open(path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=4)
    f.write("\n")
PY
}

warn_placeholder_passphrase() {
	local cfg="${HBDIR}/config/config.json"
	[ -f "$cfg" ] || return 0
	if grep -q '"passphrase": "CHANGE-ME"' "$cfg" 2>/dev/null; then
		warn "config.json still has passphrase CHANGE-ME — set a real one before going live."
	fi
}

ensure_config() {
	mkdir -p "${HBDIR}/config" "${HBDIR}/dashboard/data" "${HBLINK4_LOGDIR}"
	chmod 0755 "${HBDIR}" "${HBDIR}/config" "${HBDIR}/dashboard" "${HBDIR}/dashboard/data" "${HBLINK4_LOGDIR}"

	if [ ! -f "${HBDIR}/config/config.json" ]; then
		note "Downloading engine config_sample.json from n0mjs710/HBlink4..."
		if _download_sample "$SAMPLE_ENGINE_URL" "${HBDIR}/config/config.json" \
			"${HBLINK4_SRC}/config/config_sample.json"; then
			patch_tcp_events "${HBDIR}/config/config.json" engine || {
				err "Failed to patch engine config for TCP events"
				return 1
			}
			ok "Wrote ${HBDIR}/config/config.json (TCP events, unix sample patched)"
		else
			err "Could not obtain engine config_sample.json"
			return 1
		fi
	fi

	if [ ! -f "${HBDIR}/dashboard/config.json" ]; then
		note "Downloading dashboard config_sample.json from n0mjs710/HBlink4..."
		if _download_sample "$SAMPLE_DASH_URL" "${HBDIR}/dashboard/config.json" \
			"${HBLINK4_SRC}/dashboard/config_sample.json"; then
			patch_tcp_events "${HBDIR}/dashboard/config.json" dash || {
				err "Failed to patch dashboard config for TCP events"
				return 1
			}
			ok "Wrote ${HBDIR}/dashboard/config.json (TCP events, unix sample patched)"
		else
			err "Could not obtain dashboard config_sample.json"
			return 1
		fi
	fi

	warn_placeholder_passphrase
	return 0
}

install_compose_tree() {
	local src="$1"
	mkdir -p "${HBDIR}/docker/hblink4" "${HBDIR}/docker/dashboard" "${HBDIR}/lib" "${HBDIR}/apache"
	sed -i 's/\r$//' "${src}/docker-compose.yml" 2>/dev/null || true
	cp -f "${src}/docker-compose.yml" "${HBDIR}/docker-compose.yml"
	cp -f "${src}/docker/hblink4/Dockerfile" "${HBDIR}/docker/hblink4/Dockerfile"
	cp -f "${src}/docker/dashboard/Dockerfile" "${HBDIR}/docker/dashboard/Dockerfile"
	if [ -f "${src}/files/apache-hblink4-dash.conf" ]; then
		cp -f "${src}/files/apache-hblink4-dash.conf" "${HBDIR}/apache/hblink4-dash.conf"
		chmod 644 "${HBDIR}/apache/hblink4-dash.conf"
	fi
	if [ -f "${src}/docker/.dockerignore" ]; then
		cp -f "${src}/docker/.dockerignore" "${HBLINK4_SRC}/.dockerignore" 2>/dev/null || true
	fi
	if [ -f "${src}/lib/common.sh" ]; then
		cp -f "${src}/lib/common.sh" "${HBDIR}/lib/common.sh"
	fi
	printf 'PYTHON_IMAGE=%s\n' "${PYTHON_IMAGE:-$PYTHON_IMAGE_DEFAULT}" > "${HBDIR}/.env"
	chmod 644 "${HBDIR}/docker-compose.yml" "${HBDIR}/.env"
}

clone_or_pull_hblink4() {
	if [ -d "${HBLINK4_SRC}/.git" ]; then
		note "Updating ${HBLINK4_SRC} from git..."
		git -C "${HBLINK4_SRC}" pull --ff-only || warn "git pull of HBlink4 failed — using local tree"
	else
		note "Cloning n0mjs710/HBlink4 to ${HBLINK4_SRC}..."
		mkdir -p "$(dirname "${HBLINK4_SRC}")"
		git clone "${HBLINK4_REPO}" "${HBLINK4_SRC}"
	fi
	[ -f "${HBLINK4_SRC}/hblink4/hblink.py" ] || {
		err "HBlink4 checkout looks incomplete: missing hblink4/hblink.py"
		return 1
	}
}

build_images() {
	local extra=()
	[ "${1:-}" = "--no-cache" ] && extra+=(--no-cache --pull)
	ensure_config || return 1
	( cd "$HBDIR" && docker compose build "${extra[@]}" )
}

# If 3.14 dmr_utils3/bitarray fails, retry images on 3.13
build_images_with_fallback() {
	local extra=()
	[ "${1:-}" = "--no-cache" ] && extra+=(--no-cache --pull)
	ensure_config || return 1
	if ( cd "$HBDIR" && PYTHON_IMAGE="${PYTHON_IMAGE:-$PYTHON_IMAGE_DEFAULT}" docker compose build "${extra[@]}" ); then
		return 0
	fi
	warn "Build on ${PYTHON_IMAGE:-$PYTHON_IMAGE_DEFAULT} failed — retrying ${PYTHON_IMAGE_FALLBACK} (dmr_utils3 wheel fallback)"
	printf 'PYTHON_IMAGE=%s\n' "$PYTHON_IMAGE_FALLBACK" > "${HBDIR}/.env"
	( cd "$HBDIR" && PYTHON_IMAGE="$PYTHON_IMAGE_FALLBACK" docker compose build "${extra[@]}" )
}

set_permissions() {
	chmod 0755 "$HBDIR" "$HBLINK4_LOGDIR" "${HBDIR}/dashboard/data" 2>/dev/null || true
	chown -R "${RADIO_UID}" "$HBDIR" "$HBLINK4_LOGDIR" 2>/dev/null || true
	chmod 644 "${HBDIR}/config/config.json" "${HBDIR}/dashboard/config.json" "${HBDIR}/docker-compose.yml" 2>/dev/null || true
}

install_control_scripts() {
	local src="$1"
	local sbin="${src}/usr/local/sbin"
	mkdir -p /usr/local/lib/hblink4 /usr/local/sbin
	cp -f "${src}/lib/common.sh" /usr/local/lib/hblink4/common.sh
	chmod 644 /usr/local/lib/hblink4/common.sh
	local name
	for name in menu initial-setup start stop restart flush logs update upgrade uninstall diagnostics ssl; do
		cp -p "${sbin}/${name}" "/usr/local/sbin/hblink4-${name}"
		chmod 755 "/usr/local/sbin/hblink4-${name}"
	done
	mkdir -p "$HBDIR"
	echo "$src" > "${HBDIR}/.installer_path"
	chmod 644 "${HBDIR}/.installer_path"
}

source_hblink4_lib() {
	:
}

# Each sbin script sources this file; nothing else to do.
true
