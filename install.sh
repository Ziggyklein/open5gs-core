set -euo pipefail

sudo apt update -y
sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  iproute2 \
  kmod \
  iptables \
  docker.io \
  docker-compose-plugin

sudo systemctl enable --now docker

sudo modprobe tun  || true
sudo modprobe sctp || true

sudo mkdir -p /dev/net
sudo test -c /dev/net/tun || sudo mknod /dev/net/tun c 10 200
sudo chmod 0666 /dev/net/tun

sudo sysctl -w net.ipv4.ip_forward=1
sudo sh -c 'echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-open5gs.conf'
sudo sysctl -p /etc/sysctl.d/99-open5gs.conf

echo "[done] install.sh klaar"

