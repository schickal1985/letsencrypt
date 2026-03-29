# Certbot Let's Encrypt Wrapper (Sequentielle Version)

Dieses Projekt stellt ein Bash-Wrapper-Skript (`update_certbot`) zur automatisierten und interaktiven Erstellung von Let's Encrypt Zertifikaten über den DNS-01 Challenge-Typ bereit.

## Übersicht

Das Hauptskript führt den Benutzer durch die Anforderung von Zertifikaten (inklusive Wildcards) für eine oder mehrere Domains. Es nutzt dabei das Tool `expect` um den Ablauf von certbot zu automatisieren und wartet automatisch darauf, dass die DNS-Einträge global (Google und Cloudflare DNS) propagiert sind, bevor der Prozess fortgesetzt wird.

## Voraussetzungen

- Root-Rechte (`sudo`)
- Das Paket `expect` muss installiert sein (`sudo apt-get install -y expect`)
- `certbot` muss installiert sein

## Dateien im Repository

- `update_certbot`: Das Hauptskript, das ausgeführt wird. Fragt Domains ab und steuert den Certbot-Prozess via `expect`.
- `dns_checker.sh`: Ein Hilfsskript, das aufgerufen wird, bevor Certbot bestätigt wird. Es prüft aktiv gegen externe Nameserver, ob die TXT-Records weltweit sichtbar sind.
- `dns_wait_hook.sh`: Ein Authentifizierungs-Hook für den Certbot-Prozess.
- `test_ssl_batch.bat`: Ein optionales Batch-Skript für Testzwecke unter Windows.

## Verwendung

Führe das Hauptskript als root aus:

```bash
sudo ./update_certbot
```

Folge anschließend den interaktiven Anweisungen, um deine Domains und Wildcard-Präferenzen einzugeben. Das Skript lädt nach erfolgreicher Arbeit automatisch deinen Webserver (Apache2 oder Nginx) neu und führt abschließend einen Online-Check der Zertifikate aus.

## Lösung C (Sequentielle Abarbeitung)
Die Skripte (in Version 1.5) setzen auf "Lösung C": Sie arbeiten Zertifikate sequentiell pro Domain ab, isolieren diese Anfragen voneinander und warten beim DNS-01 Challenge intelligent ab, bis die TXT-Records zur Validierung sicher bereitstehen.
