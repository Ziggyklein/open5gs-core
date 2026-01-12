#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IFACE="${IFACE:-eth0}"

SUDO=""
if [ "${EUID:-$(id -u)}" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

echo "[prep] Ensuring tun module and device"
if ! lsmod | awk '{print $1}' | grep -qx tun; then
  ${SUDO}modprobe tun
fi
if [ ! -c /dev/net/tun ]; then
  ${SUDO}mkdir -p /dev/net
  ${SUDO}mknod /dev/net/tun c 10 200
  ${SUDO}chmod 0666 /dev/net/tun
fi

echo "[prep] Enabling IPv4 forwarding"
${SUDO}sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo "[prep] Adding NAT masquerade on ${IFACE}"
if ! ${SUDO}iptables -t nat -C POSTROUTING -o "${IFACE}" -j MASQUERADE >/dev/null 2>&1; then
  ${SUDO}iptables -t nat -A POSTROUTING -o "${IFACE}" -j MASQUERADE
fi

echo "[docker] Pulling images"
cd "${ROOT}"
${SUDO}docker compose pull

echo "[docker] Starting core"
${SUDO}docker compose up -d

echo "[docker] Status"
${SUDO}docker compose ps

echo "[logs] Tail (amf/smf/upf)"
${SUDO}docker compose logs --tail 50 amf smf upf || true
