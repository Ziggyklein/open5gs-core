#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- sudo helper -----------------------------------------------------------
SUDO=""
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "[error] Not running as root and 'sudo' not found. Run as root or install sudo." >&2
    exit 1
  fi
fi

run() {
  # Run a command with sudo if needed
  if [ -n "${SUDO}" ]; then
    sudo "$@"
  else
    "$@"
  fi
}

# ---- pick outgoing interface ----------------------------------------------
# If IFACE is not set, try to detect the default route interface.
IFACE="${IFACE:-}"
if [ -z "${IFACE}" ]; then
  IFACE="$(ip route 2>/dev/null | awk '/^default/ {print $5; exit}')"
fi
IFACE="${IFACE:-eth0}"

# ---- prerequisites ---------------------------------------------------------
cd "${ROOT}"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker not found. Install Docker first." >&2
  exit 1
fi

# Prefer 'docker compose' (plugin). Fall back to 'docker-compose' if needed.
COMPOSE=(docker compose)
if ! docker compose version >/dev/null 2>&1; then
  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
  else
    echo "[error] docker compose not available (no plugin and no docker-compose). Install docker compose." >&2
    exit 1
  fi
fi

# ---- tun -------------------------------------------------------------------
echo "[prep] Ensuring tun module and device"
if ! command -v lsmod >/dev/null 2>&1; then
  echo "[warn] lsmod not found; skipping module check and trying modprobe tun anyway"
  run modprobe tun || true
else
  if ! lsmod | awk '{print $1}' | grep -qx tun; then
    run modprobe tun || true
  fi
fi

if [ ! -c /dev/net/tun ]; then
  run mkdir -p /dev/net
  # Create tun device if missing
  run mknod /dev/net/tun c 10 200 || true
  run chmod 0666 /dev/net/tun
fi

# ---- sysctl ----------------------------------------------------------------
echo "[prep] Enabling IPv4 forwarding"
run sysctl -w net.ipv4.ip_forward=1 >/dev/null

# ---- NAT -------------------------------------------------------------------
echo "[prep] Adding NAT masquerade on ${IFACE}"
if command -v iptables >/dev/null 2>&1; then
  if ! run iptables -t nat -C POSTROUTING -o "${IFACE}" -j MASQUERADE >/dev/null 2>&1; then
    run iptables -t nat -A POSTROUTING -o "${IFACE}" -j MASQUERADE
  fi
else
  echo "[warn] iptables not found; skipping NAT rule. UE internet may not work until NAT is configured." >&2
fi

# ---- docker compose --------------------------------------------------------
echo "[docker] Pulling images"
run "${COMPOSE[@]}" pull

echo "[docker] Starting core"
run "${COMPOSE[@]}" up -d

echo "[docker] Status"
run "${COMPOSE[@]}" ps

echo "[logs] Tail (amf/smf/upf)"
run "${COMPOSE[@]}" logs --tail 50 amf smf upf || true
