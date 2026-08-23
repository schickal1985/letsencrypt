# Certbot Let's Encrypt Wrapper (Sequentielle Version)

Dieses Projekt stellt ein Bash-Wrapper-Skript (`update_certbot`) zur automatisierten und interaktiven Erstellung von Let's Encrypt Zertifikaten über den DNS-01 Challenge-Typ bereit.

## Übersicht

Das Hauptskript führt den Benutzer durch die Anforderung von Zertifikaten (inklusive Wildcards) für eine oder mehrere Domains. Es nutzt dabei das Tool `expect` um den Ablauf von certbot zu automatisieren und wartet automatisch darauf, dass die DNS-Einträge global (Google, Cloudflare und OpenDNS DNS) propagiert sind, bevor der Prozess fortgesetzt wird.

## Voraussetzungen

- Root-Rechte (`sudo`)
- Erforderliche Pakete: `expect`, `dnsutils` (enthält `dig`), `openssl`, `certbot`
  - Einmalige Installation (Debian/Ubuntu):
    ```bash
    sudo apt-get update && sudo apt-get install -y expect dnsutils openssl certbot
    ```

## Dateien im Repository

- `update_certbot`: Das Hauptskript, das ausgeführt wird. Führt Pre-Flight Checks durch, fragt Domains ab, verwaltet temporäre Arbeitsdaten sicher per `trap` und steuert den Certbot-Prozess via `expect`.
- `dns_checker.sh`: Ein Hilfsskript, das aufgerufen wird, bevor Certbot bestätigt wird. Es prüft aktiv gegen externe Nameserver (Google, Cloudflare und OpenDNS), ob die TXT-Records weltweit sichtbar sind, und stellt den Fortschritt in einem kompakten In-Place-Dashboard mit einer Sanduhr-Animation und Countdown dar.
- `dns_wait_hook.sh`: Ein Authentifizierungs-Hook für den Certbot-Prozess.
- `sed.sh`: Kleines Hilfsskript zur Bereinigung von Windows-Zeilenumbrüchen (CRLF -> LF).
- `test_ssl_batch.bat`: Ein optionales Batch-Skript für Live-Tests unter Windows.

## Verwendung

Führe das Hauptskript als root aus:

```bash
sudo ./update_certbot
```

Folge anschließend den interaktiven Anweisungen, um deine Domains und Wildcard-Präferenzen einzugeben. Das Skript lädt nach erfolgreicher Arbeit automatisch deine Webserver (Apache2 und/oder Nginx) neu und führt abschließend einen Online-Check der Zertifikate aus.

## Lösung C (Sequentielle Abarbeitung)
Die Skripte (in Version 1.9.5) setzen auf "Lösung C": Sie arbeiten Zertifikate sequentiell pro Domain ab, isolieren diese Anfragen voneinander und warten beim DNS-01 Challenge intelligent ab, bis die TXT-Records zur Validierung sicher bereitstehen.
