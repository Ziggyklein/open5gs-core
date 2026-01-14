// mongo-init-subscriber.js
db = db.getSiblingDB("open5gs");

const imsi   = process.env.IMSI;
const msisdn = process.env.MSISDN;
const k      = process.env.K;
const opc    = process.env.OPC;
const amf    = process.env.AMF;
const sst    = parseInt(process.env.SST || "1");
const sd     = process.env.SD || "010203";

if (!imsi || !k || !opc) {
  print("[mongo-init] ontbrekende env variabelen, skip");
  quit();
}

const exists = db.subscribers.findOne({ imsi });
if (exists) {
  print(`[mongo-init] subscriber ${imsi} bestaat al`);
  quit();
}

db.subscribers.insertOne({
  imsi,
  msisdn,
  access_restriction_data: 32,
  slice: [{ sst, sd }],
  ambr: {
    uplink:   { value: 1, unit: 3 },
    downlink: { value: 1, unit: 3 }
  },
  security: { k, opc, amf }
});

print(`[mongo-init] subscriber ${imsi} aangemaakt`);
