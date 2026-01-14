#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# laad .env
set -a
[ -f .env ] && source .env
set +a

# verwacht deze keys in .env (pas namen aan als jij andere gebruikt)
: "${IMSI:?Missing IMSI in .env}"
: "${K:?Missing K in .env}"
: "${OPC:?Missing OPC in .env}"
: "${AMF:=8000}"
: "${SST:=1}"
: "${SD:=010203}"
: "${MSISDN:=}"

# wacht tot mongo echt ready is
echo "[seed] waiting for mongo..."
until sudo docker exec mongo mongo --quiet --eval "db.adminCommand('ping').ok" >/dev/null 2>&1; do
  sleep 1
done

echo "[seed] upserting subscriber IMSI=$IMSI"

# Upsert (bestaat al -> update; bestaat niet -> insert)
sudo docker exec -i mongo mongo open5gs --quiet <<EOF
db = db.getSiblingDB("open5gs");

const imsi = "$IMSI";
const msisdn = "$MSISDN";
const k = "$K";
const opc = "$OPC";
const amf = "$AMF";
const sst = Number("$SST");
const sd = "$SD";

db.subscribers.updateOne(
  { imsi: imsi },
  {
    \$set: {
      imsi: imsi,
      msisdn: msisdn || undefined,
      access_restriction_data: 32,
      slice: [{ sst: sst, sd: sd }],
      ambr: {
        uplink:   { value: 1, unit: 3 },
        downlink: { value: 1, unit: 3 }
      },
      security: { k: k, opc: opc, amf: amf }
    }
  },
  { upsert: true }
);

print("[seed] done");
EOF
