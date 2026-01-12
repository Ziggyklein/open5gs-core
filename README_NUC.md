# Open5GS NUC Quickstart

## Vereisten
- Ubuntu/Debian met Docker en Docker Compose plugin (`docker compose`).
- Kernel SCTP ondersteuning (installatie van `libsctp1`/`lksctp-tools` en enabled module).
- `tun` kernelmodule en `/dev/net/tun` beschikbaar.
- Toegang om `modprobe`, `sysctl` en `iptables` aan te roepen (root of sudo).

## Starten
Vanuit deze map:
```
IFACE=enp2s0 ./run-core.sh
```
`IFACE` is de host-interface voor NAT (default `eth0`).

## Reset
```
./reset-db.sh
```
Verwijdert ook de MongoDB data volume (abonnee-gegevens kwijt).

## UERANSIM koppelen
- gNB naar HOST-IP poort `38412/sctp` (NGAP > AMF).
- GTP-U naar HOST-IP poort `2152/udp` (UPF).
