# Certbot Let's Encrypt Wrapper (Sequentielle Version)

Dieses Projekt stellt ein Bash-Wrapper-Skript (`update_certbot`) zur automatisierten und interaktiven Erstellung von Let's Encrypt Zertifikaten über den DNS-01 Challenge-Typ bereit.

## Übersicht

Das Hauptskript führt den Benutzer durch die Anforderung von Zertifikaten im festen Modus **Root + www** (`domain.de` + `www.domain.de`) für eine oder mehrere Domains. Es setzt vor jedem Durchlauf eventuell gecachte Let's Encrypt-Freigaben zurück (sodass immer zuverlässig 2 frische TXT-Codes erstellt werden), nutzt `expect` zur Steuerung von Certbot und prüft die DNS-Einträge direkt auf den **autoritativen Nameservern** der jeweiligen Domain (inklusive Warnung bei versehentlich mitkopierten Leerzeichen). Sobald 3 Checks in Folge `OK` melden, wird das Zertifikat sofort ausgestellt.

## Voraussetzungen

- Root-Rechte (`sudo`)
- Erforderliche Pakete: `expect`, `dnsutils` (enthält `dig`), `openssl`, `certbot`
  - Einmalige Installation (Debian/Ubuntu):
    ```bash
    sudo apt-get update && sudo apt-get install -y expect dnsutils openssl certbot
    ```

## Dateien im Repository

- `update_certbot`: Das Hauptskript, das ausgeführt wird. Führt Pre-Flight Checks durch, fragt die Domains ab (immer im Modus `Root + www`), setzt gecachte ACME-Autorisierungen zurück, steuert den Certbot-Prozess via `expect` und wertet den echten Exit-Code von Certbot sowie das ausgestellte Zertifikat aus.
- `dns_checker.sh`: Ein Hilfsskript, das aufgerufen wird, bevor Certbot bestätigt wird. Es ermittelt automatisch die autoritativen Nameserver der Domain und prüft diese direkt auf exakte Übereinstimmung (inkl. Leerzeichen-Erkennung). Nach 3 erfolgreichen Checks in Folge gibt es sofort grünes Licht.
- `dns_wait_hook.sh`: Ein Authentifizierungs-Hook für den Certbot-Prozess (nummeriert die 2 TXT-Codes pro Domain übersichtlich durch).
- `sed.sh`: Kleines Hilfsskript zur Bereinigung von Windows-Zeilenumbrüchen (CRLF -> LF).
- `test_ssl_batch.bat`: Ein optionales Batch-Skript für Live-Tests unter Windows.

## Verwendung

Führe das Hauptskript als root aus:

```bash
sudo ./update_certbot
```

Folge anschließend den interaktiven Anweisungen, um deine Domains einzugeben. Das Skript lädt nach erfolgreicher Arbeit automatisch deine Webserver (Apache2 und/oder Nginx) neu und führt abschließend einen Online-Check der Zertifikate aus.

## Version 2.0.0 (Sequentielle Abarbeitung & Autoritative Nameserver-Prüfung)
Die Skripte (in Version 2.0.0) arbeiten Zertifikate sequentiell pro Domain im Modus `Root + www` (2 TXT-Codes) ab, erzwingen bei jedem Start 2 frische Challenges und prüfen beim DNS-01 Challenge direkt die autoritativen Nameserver der jeweiligen Domain.
