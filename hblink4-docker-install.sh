#!/bin/bash
# Version 0.1.0 (06092026) hblink4-docker-installer
#
##################################################################################
#   Copyright (C) 2026 Shane Daley, M0VUB aka ShaYmez. <shane@freestar.network>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software Foundation,
#   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
##################################################################################
#
# One-shot installer for HBlink4 (engine + dashboard) in Docker Compose v2.
# HBlink4 itself is Copyright (C) 2016-2025 Cortney T. Buffington, N0MJS.
# This script only installs and containers that software.
#
# Debian 11 / 12 / 13 and Ubuntu 22.04 / 24.04 LTS. Must run as root.
# Commands after install:  docker compose  (Compose v2, space — not hyphen)

export DEBIAN_FRONTEND=noninteractive

DIRDIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib/common.sh
if [ -f "${DIRDIR}/lib/common.sh" ]; then
	. "${DIRDIR}/lib/common.sh"
elif [ -f /usr/local/lib/hblink4/common.sh ]; then
	. /usr/local/lib/hblink4/common.sh
else
	echo "ERROR: lib/common.sh not found"
	exit 1
fi

strip_crlf() {
	local f
	while IFS= read -r -d '' f; do
		sed -i 's/\r$//' "$f" 2>/dev/null || true
	done < <(find "$1" -type f \( -name '*.sh' -o -name '*.yml' -o -name 'Dockerfile' -o -path '*/usr/local/sbin/*' -o -path '*/lib/*' \) -print0 2>/dev/null)
}

require_root

# Detect OS type and version
if [ -f /etc/os-release ]; then
	. /etc/os-release
	OS=$ID
	OS_VERSION=$VERSION_ID
else
	err "Cannot detect operating system"
	exit 1
fi

if [ "$OS" != "debian" ] && [ "$OS" != "ubuntu" ]; then
	err "This script only supports Debian and Ubuntu. Detected: $OS"
	exit 1
fi

if [ "$OS" = "ubuntu" ]; then
	if [ "$OS_VERSION" != "22.04" ] && [ "$OS_VERSION" != "24.04" ]; then
		err "Only Ubuntu 22.04 LTS and 24.04 LTS are supported (got $OS_VERSION)"
		exit 1
	fi
	ok "Detected: Ubuntu $OS_VERSION LTS"
fi

if [ "$OS" = "debian" ]; then
	VERSION=$(sed 's/\..*//' /etc/debian_version)
	if [ "$VERSION" != "11" ] && [ "$VERSION" != "12" ] && [ "$VERSION" != "13" ]; then
		err "Only Debian 11, 12, and 13 are supported (got $VERSION)"
		exit 1
	fi
	ok "Detected: Debian $VERSION"
fi

LOCAL_IP="$(host_ip)"
ARC=$(lscpu 2>/dev/null | awk '/Architecture/ {print $2; exit}')
DEP="wget curl git sudo python3 conntrack sed ca-certificates gnupg lsb-release nano"

print_banner
echo "------------------------------------------------------------------------------"
echo "Downloading and installing required software & dependencies....."
echo "------------------------------------------------------------------------------"

install_docker_and_dependencies() {
	note "Installing Docker Engine and host packages..."
	apt-get update
	apt-get install -y $DEP
	sleep 1

	note "Removing old Docker versions if present..."
	apt-get remove docker docker-engine docker.io containerd runc docker-compose 2>/dev/null || true

	if [ "$OS" = "ubuntu" ]; then
		DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"
	else
		DOCKER_REPO_URL="https://download.docker.com/linux/debian"
	fi

	note "Adding Docker GPG key..."
	rm -f /usr/share/keyrings/docker-archive-keyring.gpg
	curl -fsSL "${DOCKER_REPO_URL}/gpg" | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
		err "Failed to download Docker GPG key"
		exit 1
	fi

	note "Adding Docker repository..."
	echo \
	"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] ${DOCKER_REPO_URL} \
	$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

	apt-get update
	if ! apt-get install -y docker-ce docker-ce-cli containerd.io; then
		err "Failed to install Docker Engine"
		exit 1
	fi
	if ! command -v docker >/dev/null 2>&1; then
		err "Docker installation failed — docker command not found"
		exit 1
	fi

	note "Installing Docker Compose v2 plugin..."
	if ! apt-get install -y docker-compose-plugin; then
		err "Failed to install docker-compose-plugin"
		exit 1
	fi
	if ! docker compose version >/dev/null 2>&1; then
		err "Docker Compose v2 installation failed — 'docker compose' not working"
		exit 1
	fi

	systemctl enable docker
	systemctl start docker
	if ! systemctl is-active --quiet docker; then
		err "Docker service failed to start"
		exit 1
	fi

	note "Set userland-proxy to false and cap Docker json logs..."
	if [ -f "${DIRDIR}/files/docker-daemon.json" ]; then
		cp -f "${DIRDIR}/files/docker-daemon.json" /etc/docker/daemon.json
	else
		cat > /etc/docker/daemon.json << 'EOF'
{
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
	fi
	systemctl restart docker
	sleep 2
	ok "Docker Engine + Compose v2 ready"
}

if [ "$OS" = "debian" ]; then
	if [ "$VERSION" = "11" ] || [ "$VERSION" = "12" ] || [ "$VERSION" = "13" ]; then
		install_docker_and_dependencies
	else
		err "Operating system not supported."
		exit 1
	fi
elif [ "$OS" = "ubuntu" ]; then
	if [ "$OS_VERSION" = "22.04" ] || [ "$OS_VERSION" = "24.04" ]; then
		install_docker_and_dependencies
	else
		err "Operating system not supported."
		exit 1
	fi
fi

echo "------------------------------------------------------------------------------"
echo "Installing control scripts /usr/local/sbin....."
echo "------------------------------------------------------------------------------"
strip_crlf "$DIRDIR"
install_control_scripts "$DIRDIR"
if [ -e /usr/local/sbin/hblink4-menu ]; then
	ok "Control scripts installed"
else
	err "Control scripts did not install. Exiting."
	exit 1
fi

if [ -f "${DIRDIR}/files/hblink4-logrotate" ]; then
	cp -f "${DIRDIR}/files/hblink4-logrotate" /etc/logrotate.d/hblink4
	chmod 644 /etc/logrotate.d/hblink4
fi

echo "------------------------------------------------------------------------------"
echo "Cloning / updating HBlink4 source (n0mjs710/HBlink4)....."
echo "------------------------------------------------------------------------------"
clone_or_pull_hblink4 || exit 1
ok "HBlink4 source at ${HBLINK4_SRC}"

echo "------------------------------------------------------------------------------"
echo "Installing compose tree and configuration....."
echo "------------------------------------------------------------------------------"
install_compose_tree "$DIRDIR"
ensure_config || exit 1
set_permissions
ok "Config + compose in ${HBDIR}"

echo "------------------------------------------------------------------------------"
echo "Building local images (hblink4-engine:local + hblink4-dash:local)....."
echo "------------------------------------------------------------------------------"
if ! build_images_with_fallback; then
	err "Image build failed"
	exit 1
fi
ok "Images built"

echo "------------------------------------------------------------------------------"
echo "Starting HBlink4 stack....."
echo "------------------------------------------------------------------------------"
cd "$HBDIR" || exit 1
docker compose up -d
sleep 6
docker ps --filter name=hblink4
echo
docker compose logs --tail=40
echo

clear
print_banner
note "HBlink first-time setup....."
if [ -t 0 ]; then
	hblink4-initial-setup
else
	echo "Non-interactive session: skipping first-time setup menu."
	echo "Run 'hblink4-menu' or 'hblink4-initial-setup' to configure."
fi

echo
echo "${C_CYAN}*************************************************************************${C_RESET}"
echo
echo "                 The HBlink4 Docker Install Is Complete!"
echo
echo "              ******* To Update run 'hblink4-update' *******"
echo "              ******* Clean rebuild: 'hblink4-upgrade' ******"
echo
echo "     Use 'hblink4-logs' or 'docker compose logs -f --tail=50'"
echo "         File logs: ${HBLINK4_LOGDIR}/hblink.log"
echo "         Dashboard: http://${LOCAL_IP:-<host>}:8080"
echo "         HTTPS:     hblink4-ssl <fqdn> <email>  (optional, port 443)"
echo "         Repeaters: UDP 62031  (passphrase in config.json)"
echo
echo "                    Type 'hblink4-menu' for main menu"
echo
echo "        HBlink4: https://github.com/n0mjs710/HBlink4"
echo "        Copyright (C) Cortney T. Buffington, N0MJS"
echo
echo "        Installer: https://github.com/ShaYmez/hblink4-docker-install"
echo "        Copyright © 2026 Shane Daley - M0VUB  Aka ShaYmez"
echo "        <shane@freestar.network>"
echo
echo "                      Your IP address is ${LOCAL_IP:-unknown}"
if [ "$OS" = "ubuntu" ]; then
	echo "               You're running on ${ARC:-?} with Ubuntu ${OS_VERSION} LTS"
else
	echo "               You're running on ${ARC:-?} with Debian ${VERSION}"
fi
echo
echo "------------------------------------------------------------------------------"
echo "                          Installed Versions"
echo "------------------------------------------------------------------------------"
docker --version
docker compose version
echo "Note: This installation uses Docker Compose v2 (docker compose command)"
echo "------------------------------------------------------------------------------"
echo
echo "                     Thanks for using this script."
echo "                 Copyright © 2026 Shane Daley - M0VUB"
echo "                              Aka ShaYmez"
echo
echo "${C_CYAN}*************************************************************************${C_RESET}"
exit 0
