#!/usr/bin/env bash
set -euo pipefail

# One-command bringup for Ubuntu 24.04:
# - Installs prerequisites + Docker Engine + docker compose plugin (if missing)
# - Ensures kernel modules (tun, sctp) and /dev/net/tun
# - Enables IPv4 forwarding + adds NAT masquerade
# - Starts Open5GS stack via docker compose

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- sudo helper -----------------------------------------------------------
SUDO=""
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "[error] Not running as root and 'sudo' is not installed. Install sudo or run as root." >&2
    exit 1
  fi
fi

run() {
  if [ -n "${SUDO}" ]; then
    sudo "$@"
  else
    "$@"
  fi
}

# ---- ensure basic tools ----------------------------------------------------
ensure_packages() {
  local pkgs=("$@")
  echo "[install] Ensuring packages: ${pkgs[*]}"
  run apt-get update -y
  run apt-get install -y "${pkgs[@]}"
}

# ---- detect default interface ---------------------------------------------
detect_iface() {
  # Prefer env IFACE; else detect default route interface; else fall back to eth0.
  if [ -n "${IFACE:-}" ]; then
    echo "${IFACE}"
    return
  fi
  local d
  d="$(ip route 2>/dev/null | awk '/^default/ {print $5; exit}' || true)"
  if [ -n "${d}" ]; then
    echo "${d}"
  else
    echo "eth0"
  fi
}

IFACE="$(detect_iface)"
UE_SUBNET="${UE_SUBNET:-}"   # optional: restrict NAT to UE subnet, e.g. UE_SUBNET="10.45.0.0/16"

cd "${ROOT}"

# ---- prerequisites (host) --------------------------------------------------
# iproute2 gives `ip`, kmod gives `modprobe/lsmod`, iptables for NAT, curl/gnupg/ca-certificates for Docker repo
ensure_packages ca-certificates curl gnupg lsb-release iproute2 kmod iptables

# ---- install Docker (if missing) ------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "[install] Docker not found. Installing Docker Engine + Compose plugin..."

  # Set up Docker APT repo (official)
  run install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | run gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    run chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  . /etc/os-release
  # Ubuntu 24.04 => VERSION_CODENAME=noble
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    | run tee /etc/apt/sources.list.d/docker.list >/dev/null

  run apt-get update -y
  run apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  run systemctl enable --now docker
else
  # Ensure docker daemon is running
  if command -v systemctl >/dev/null 2>&1; then
    run systemctl enable --now docker >/dev/null 2>&1 || true
  fi
fi

# ---- choose compose command ------------------------------------------------
COMPOSE=(docker compose)
if ! docker compose version >/dev/null 2>&1; then
  echo "[error] 'docker compose' is not available. Install docker-compose-plugin." >&2
  exit 1
fi

# ---- kernel modules & tun device ------------------------------------------
echo "[prep] Ensuring kernel modules (tun, sctp) and /dev/net/tun"
run modprobe tun  >/dev/null 2>&1 || true
run modprobe sctp >/dev/null 2>&1 || true

if [ ! -c /dev/net/tun ]; then
  run mkdir -p /dev/net
  # Create tun device if missing (usually created automatically by udev, but just in case)
  run mknod /dev/net/tun c 10 200 || true
  run chmod 0666 /dev/net/tun
fi

# ---- IPv4 forwarding -------------------------------------------------------
echo "[prep] Enabling IPv4 forwarding (runtime)"
run sysctl -w net.ipv4.ip_forward=1 >/dev/null

# Optional: persist forwarding across reboot
if [ ! -f /etc/sysctl.d/99-open5gs.conf ] || ! grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.d/99-open5gs.conf 2>/dev/null; then
  echo "[prep] Persisting IPv4 forwarding in /etc/sysctl.d/99-open5gs.conf"
  echo "net.ipv4.ip_forward=1" | run tee /etc/sysctl.d/99-open5gs.conf >/dev/null
fi

# ---- NAT masquerade --------------------------------------------------------
echo "[prep] Adding NAT masquerade on interface: ${IFACE}"
if [ -n "${UE_SUBNET}" ]; then
  # Restrict NAT to UE subnet (recommended if you know it)
  if ! run iptables -t nat -C POSTROUTING -s "${UE_SUBNET}" -o "${IFACE}" -j MASQUERADE >/dev/null 2>&1; then
    run iptables -t nat -A POSTROUTING -s "${UE_SUBNET}" -o "${IFACE}" -j MASQUERADE
  fi
else
  # Broad NAT (works out-of-the-box, less strict)
  if ! run iptables -t nat -C POSTROUTING -o "${IFACE}" -j MASQUERADE >/dev/null 2>&1; then
    run iptables -t nat -A POSTROUTING -o "${IFACE}" -j MASQUERADE
  fi
fi

# ---- sanity checks: compose file exists -----------------------------------
if [ ! -f "${ROOT}/docker-compose.yml" ] && [ ! -f "${ROOT}/compose.yml" ]; then
  echo "[error] No docker-compose.yml (or compose.yml) found in ${ROOT}." >&2
  exit 1
fi

# ---- start stack -----------------------------------------------------------
echo "[docker] Pulling images"
run "${COMPOSE[@]}" pull

echo "[docker] Starting core"
run "${COMPOSE[@]}" up -d

echo "[docker] Status"
run "${COMPOSE[@]}" ps

echo "[logs] Tail (amf/smf/upf)"
run "${COMPOSE[@]}" logs --tail 80 amf smf upf || true

echo "[done] If you need NAT restricted to UE subnet, run like:"
echo "       UE_SUBNET=10.45.0.0/16 IFACE=${IFACE} ./run-core.sh"
