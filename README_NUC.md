Open5GS Core

Headless Open5GS core. Geen WebUI.

Configuratie:
.env

Installatie (eenmalig per machine):
./install.sh

Starten / toepassen wijzigingen:
./up.sh

Wijzigingen in .env worden toegepast door install.sh en up.sh opnieuw te draaien.

Reset (verwijdert alle subscriber data):
./reset-db.sh

Aansluitpunten:
AMF (NGAP / SCTP): HOST-IP:38412
UPF (GTP-U / UDP): HOST-IP:2152


checken op subscribers:
sudo docker exec mongo mongo open5gs --quiet --eval 'db.subscribers.find({}, {imsi:1}).pretty()'


