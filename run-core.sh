#!/usr/bin/env bash

sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  iproute2 \
  kmod \
  iptables

sudo apt install -y \
  docker.io \
  docker-compose-plugin
  
sudo systemctl enable --now docker

sudo modprobe tun  || true
sudo modprobe sctp || true

sudo mkdir -p /dev/net \
  test -c /dev/net/tun || mknod /dev/net/tun c 10 200 \
  chmod 0666 /dev/net/tun

sudo sysctl -w net.ipv4.ip_forward=1
sudo sh -c 'echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-open5gs.conf'
sudo sysctl -p /etc/sysctl.d/99-open5gs.conf

IFACE=$(ip route | awk '/default/ {print $5; exit}')
sudo iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null || true

cd ~/open5gsgith/open5gs-core

docker compose pull
docker compose up -d
docker compose ps
docker compose logs --tail=50 amf smf upf
