#!/bin/bash
# Static checks for hblink4-docker-install. Safe to run without root.
# Usage: bash tests/check.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FAIL=0
PASS=0

ok() { echo "OK    $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL  $1"; FAIL=$((FAIL + 1)); }

SBIN_SCRIPTS="menu initial-setup start stop restart flush logs update upgrade uninstall diagnostics ssl"

echo "=== hblink4-docker-install checks ==="
echo "ROOT=$ROOT"
echo ""

for f in \
	hblink4-docker-install.sh \
	docker-compose.yml \
	VERSION \
	CHANGELOG.md \
	README.md \
	LICENSE \
	lib/common.sh \
	files/docker-daemon.json \
	files/hblink4-logrotate \
	files/apache-hblink4-dash.conf \
	docker/hblink4/Dockerfile \
	docker/dashboard/Dockerfile \
	docker/.dockerignore
do
	if [ -f "$f" ]; then
		ok "exists $f"
	else
		bad "missing $f"
	fi
done

for s in $SBIN_SCRIPTS; do
	if [ -f "usr/local/sbin/$s" ]; then
		ok "exists usr/local/sbin/$s"
	else
		bad "missing usr/local/sbin/$s"
	fi
done

if grep -q 'install_control_scripts' hblink4-docker-install.sh; then
	ok "installer installs control scripts"
else
	bad "installer does not call install_control_scripts"
fi

if grep -q 'hblink4-ssl' usr/local/sbin/uninstall; then
	ok "uninstall removes hblink4-ssl"
else
	bad "uninstall does not remove hblink4-ssl"
fi

if grep -q 'hblink4-logs' usr/local/sbin/uninstall; then
	ok "uninstall removes hblink4-logs"
else
	bad "uninstall does not remove hblink4-logs"
fi

if grep -q 'diagnostics ssl' lib/common.sh; then
	ok "install_control_scripts includes ssl"
else
	bad "install_control_scripts missing ssl"
fi

if grep -nE '^[[:space:]]*case[[:space:]]+"\$\(read_choice\)"' usr/local/sbin/menu usr/local/sbin/initial-setup; then
	bad "read_choice used in command substitution (prompt swallowed, keys never match)"
else
	ok "menu choices not captured via \$(read_choice)"
fi

# --- no CRLF (Linux / GitHub Actions). Windows checkouts may be CRLF. ---
if [ "${CI:-}" = "true" ] || [ "$(uname -s)" = "Linux" ]; then
	CRLF_HITS=$(grep -l $'\r' hblink4-docker-install.sh docker-compose.yml lib/*.sh usr/local/sbin/* tests/*.sh docker/hblink4/Dockerfile docker/dashboard/Dockerfile 2>/dev/null || true)
	if [ -z "$CRLF_HITS" ]; then
		ok "no CRLF in scripts/yml/Dockerfile"
	else
		bad "CRLF found in: $CRLF_HITS"
	fi
else
	echo "SKIP  CRLF check on $(uname -s)"
fi

while IFS= read -r -d '' f; do
	if bash -n "$f"; then
		ok "bash -n ${f#"$ROOT"/}"
	else
		bad "bash -n ${f#"$ROOT"/}"
	fi
done < <(find "$ROOT" -type f \( -name '*.sh' -o -path '*/usr/local/sbin/*' \) -print0)

VER=$(head -1 VERSION | tr -d ' \r\n')
if echo "$VER" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
	ok "VERSION is $VER"
else
	bad "VERSION file unexpected: ${VER}"
fi

if grep -q '^version:' docker-compose.yml || grep -q '^version: ' docker-compose.yml; then
	bad "compose has root version: tag (Compose V2 should omit it)"
else
	ok "compose has no root version: tag"
fi

if grep -q 'network_mode: host' docker-compose.yml; then
	ok "compose uses network_mode: host"
else
	bad "compose missing network_mode: host"
fi

if grep -qE '^\s+ports:' docker-compose.yml; then
	bad "compose has ports: mappings (ignored/wrong with host network)"
else
	ok "compose has no ports: mappings"
fi

if grep -q 'container_name: hblink4' docker-compose.yml && grep -q 'container_name: hblink4-dash' docker-compose.yml; then
	ok "compose has hblink4 and hblink4-dash"
else
	bad "compose missing service container names"
fi

if grep -q 'hblink4-engine:local' docker-compose.yml && grep -q 'hblink4-dash:local' docker-compose.yml; then
	ok "compose uses local image tags"
else
	bad "compose local image tags"
fi

# Fail on actual v1 CLI invocations, not filenames or the v2 plugin package
if grep -nE '(^|[[:space:]])docker-compose[[:space:]]+(up|down|ps|logs|build|pull|restart)' \
	hblink4-docker-install.sh usr/local/sbin/* lib/common.sh 2>/dev/null | grep -v '^tests/'; then
	bad "found hyphenated docker-compose command"
else
	ok "only docker compose (v2 space syntax) in scripts"
fi

if grep -nE '(^|[[:space:]])whiptail[[:space:]]' hblink4-docker-install.sh usr/local/sbin/* lib/common.sh 2>/dev/null; then
	bad "whiptail still referenced"
else
	ok "no whiptail"
fi

if grep -q 'python:3.14-slim-bookworm' docker/hblink4/Dockerfile docker/dashboard/Dockerfile docker-compose.yml; then
	ok "Python 3.14-slim-bookworm base"
else
	bad "Python base image pin"
fi

if grep -vE '^\s*#' docker/hblink4/Dockerfile | grep -q 'pytest'; then
	bad "engine Dockerfile installs pytest"
else
	ok "engine Dockerfile does not install pytest"
fi

if grep -q 'user.csv' docker/hblink4/Dockerfile docker/dashboard/Dockerfile; then
	bad "Dockerfile copies user.csv"
else
	ok "Dockerfiles do not copy user.csv"
fi

if grep -q 'ensure_config' lib/common.sh && grep -q 'config_sample.json' lib/common.sh; then
	ok "ensure_config downloads samples"
else
	bad "ensure_config / sample download"
fi

if grep -q 'prune_docker_leftovers' lib/common.sh \
	&& grep -q 'prune_docker_leftovers' usr/local/sbin/update \
	&& grep -q 'prune_docker_leftovers' usr/local/sbin/upgrade \
	&& ! grep -nE 'docker[[:space:]]+system[[:space:]]+prune[[:space:]]+-a' hblink4-docker-install.sh usr/local/sbin/* lib/common.sh; then
	ok "update/upgrade prune dangling images and build cache (no prune -a)"
else
	bad "disk prune helper missing or uses docker system prune -a"
fi

if grep -q 'depends_on' docker-compose.yml && grep -A2 'container_name: hblink4$' docker-compose.yml | grep -q 'depends_on' || grep -B20 'container_name: hblink4$' docker-compose.yml | grep -q 'hblink4-dash'; then
	ok "engine depends_on dashboard (start dash first)"
else
	# looser: dash service listed before engine in file, or depends_on hblink4-dash
	if grep -q 'depends_on:' docker-compose.yml && grep -q 'hblink4-dash' docker-compose.yml; then
		ok "compose depends_on present"
	else
		bad "compose depends_on / start order"
	fi
fi

UN_OUT=$(bash usr/local/sbin/uninstall --dry-run 2>&1) || true
if printf '%s' "$UN_OUT" | grep -q 'DRY RUN'; then
	ok "uninstall --dry-run"
else
	echo "$UN_OUT"
	bad "uninstall --dry-run"
fi

UN_OUT=$(bash usr/local/sbin/uninstall --help 2>&1) || true
if printf '%s' "$UN_OUT" | grep -q 'Usage:'; then
	ok "uninstall --help"
else
	bad "uninstall --help"
fi

if grep -q '__FQDN__' files/apache-hblink4-dash.conf \
	&& grep -q 'ProxyPass /ws ws://127.0.0.1:8080/ws' files/apache-hblink4-dash.conf \
	&& grep -q 'VirtualHost \*:443' files/apache-hblink4-dash.conf; then
	ok "apache vhost templates FQDN, /ws, and 443"
else
	bad "apache vhost template missing FQDN, /ws, or 443"
fi

SSL_OUT=$(bash usr/local/sbin/ssl --help 2>&1) || true
if printf '%s' "$SSL_OUT" | grep -q 'Usage:'; then
	ok "ssl --help"
else
	echo "$SSL_OUT"
	bad "ssl --help"
fi

SSL_OUT=$(bash usr/local/sbin/ssl --dry-run ci.example.test ci@example.test 2>&1) || true
if printf '%s' "$SSL_OUT" | grep -q 'DRY RUN' \
	&& printf '%s' "$SSL_OUT" | grep -q 'ci.example.test' \
	&& printf '%s' "$SSL_OUT" | grep -q 'ProxyPass /ws' \
	&& ! printf '%s' "$SSL_OUT" | grep -q '__FQDN__'; then
	ok "ssl --dry-run"
else
	echo "$SSL_OUT"
	bad "ssl --dry-run"
fi

echo ""
echo "=== $PASS passed, $FAIL failed ==="
if [ "$FAIL" -ne 0 ]; then
	exit 1
fi
exit 0
