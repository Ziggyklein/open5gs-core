#!/usr/bin/env bash
set -euo pipefail

sudo apt update -y

# Ensure common repos exist on minimal installs
sudo apt install -y software-properties-common
sudo add-apt-repository -y universe

sudo apt update -y
sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  iproute2 \
  kmod \
  iptables

# Avoid conflicts if Ubuntu Docker is present
sudo apt remove -y docker.io docker-compose docker-compose-plugin containerd runc || true

# Docker (official repo) + Compose v2
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin

sudo systemctl enable --now docker

sudo usermod -aG docker "$USER" || true

sudo modprobe tun  || true
sudo modprobe sctp || true
printf "tun\nsctp\n" | sudo tee /etc/modules-load.d/open5gs.conf > /dev/null

sudo mkdir -p /dev/net
sudo test -c /dev/net/tun || sudo mknod /dev/net/tun c 10 200
sudo chmod 0666 /dev/net/tun

sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-open5gs.conf > /dev/null
sudo sysctl -p /etc/sysctl.d/99-open5gs.conf
sudo iptables -P FORWARD ACCEPT || true


sudo apt install -y openssh-server || true
sudo systemctl enable --now ssh || true

echo "[done] install.sh klaar"
echo "Note: log out/in once for docker group to take effect."
