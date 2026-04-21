#!/bin/bash
# Version: 1.7 (Sequentielle Version / Lösung C)
exec > /dev/tty 2>&1

# Zähle wie viele Schlüssel für diese Domain bereits angefordert wurden
COUNTER_FILE="/tmp/certbot_hook_counter_${CERTBOT_DOMAIN}"
if [ -f "$COUNTER_FILE" ]; then
    COUNT=$(cat "$COUNTER_FILE")
    COUNT=$((COUNT + 1))
else
    COUNT=1
fi
echo "$COUNT" > "$COUNTER_FILE"

echo ""
echo -e "\e[1;44m                                                        \e[0m"
echo -e "\e[1;44m   DNS-EINTRAG #${COUNT} ERFORDERLICH                          \e[0m"
echo -e "\e[1;44m                                                        \e[0m"
echo ""
echo -e "Certbot braucht einen TXT-Eintrag, um zu beweisen, dass"
echo -e "du der Besitzer von \e[1;36m${CERTBOT_DOMAIN}\e[0m bist."
echo ""
echo -e "\e[1;33m┌─────────────────────────────────────────────────────┐\e[0m"
echo -e "\e[1;33m│  Was du jetzt bei deinem DNS-Provider eintragen      │\e[0m"
echo -e "\e[1;33m│  musst (z.B. Strato, Host Europe):                   │\e[0m"
echo -e "\e[1;33m└─────────────────────────────────────────────────────┘\e[0m"
echo ""
echo -e "  Typ      :  \e[1;32mTXT\e[0m"
echo -e "  Hostname :  \e[1;32m_acme-challenge.${CERTBOT_DOMAIN}\e[0m"
echo -e "  Wert     :  \e[1;35m${CERTBOT_VALIDATION}\e[0m"
echo ""

if [ "$COUNT" -eq 1 ]; then
    echo -e "\e[1;36m──────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;36m  SCHRITT-FÜR-SCHRITT ANLEITUNG (Schlüssel #1)\e[0m"
    echo -e "\e[1;36m──────────────────────────────────────────────────────\e[0m"
    echo ""
    echo -e "  \e[1;37m1.\e[0m Melde dich bei deinem DNS-Provider an"
    echo -e "     (z.B. strato.de → Mein Konto → Domains → DNS-Verwaltung)"
    echo ""
    echo -e "  \e[1;37m2.\e[0m Klicke auf \e[1;32m'TXT-Eintrag hinzufügen'\e[0m (oder 'Neu')"
    echo ""
    echo -e "  \e[1;37m3.\e[0m Trage ein:"
    echo -e "     - Typ:      \e[1;32mTXT\e[0m"
    echo -e "     - Hostname: \e[1;32m_acme-challenge.${CERTBOT_DOMAIN}\e[0m"
    echo -e "     - Wert:     \e[1;35m${CERTBOT_VALIDATION}\e[0m"
    echo ""
    echo -e "  \e[1;37m4.\e[0m Klicke auf \e[1;32m'Speichern'\e[0m"
    echo ""
    echo -e "\e[1;33m  ⚠ ACHTUNG: Falls gleich ein 2. Schlüssel erscheint:\e[0m"
    echo -e "\e[1;33m  NICHT den ersten löschen oder überschreiben!\e[0m"
    echo -e "\e[1;33m  Einfach nochmal 'Hinzufügen' klicken und den 2. Wert\e[0m"
    echo -e "\e[1;33m  mit dem GLEICHEN Hostnamen eintragen.\e[0m"
    echo ""
else
    echo -e "\e[1;36m──────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;36m  SCHRITT-FÜR-SCHRITT ANLEITUNG (Schlüssel #${COUNT})\e[0m"
    echo -e "\e[1;36m──────────────────────────────────────────────────────\e[0m"
    echo ""
    echo -e "  \e[1;37m1.\e[0m Gehe zurück in die DNS-Verwaltung deines Providers"
    echo ""
    echo -e "  \e[1;37m2.\e[0m Klicke auf \e[1;32m'Hinzufügen'\e[0m (NICHT auf 'Update'/'Bearbeiten'!)"
    echo -e "     Der erste Eintrag muss erhalten bleiben!"
    echo ""
    echo -e "  \e[1;37m3.\e[0m Trage den 2. Eintrag ein:"
    echo -e "     - Typ:      \e[1;32mTXT\e[0m"
    echo -e "     - Hostname: \e[1;32m_acme-challenge.${CERTBOT_DOMAIN}\e[0m  ← gleicher Hostname!"
    echo -e "     - Wert:     \e[1;35m${CERTBOT_VALIDATION}\e[0m  ← anderer Wert!"
    echo ""
    echo -e "  \e[1;37m4.\e[0m Klicke auf \e[1;32m'Speichern'\e[0m"
    echo ""
fi

echo -e "\e[1;36m──────────────────────────────────────────────────────\e[0m"
echo -e "\e[1;32m  Das Skript prüft nun automatisch im Hintergrund,\e[0m"
echo -e "\e[1;32m  ob der Eintrag weltweit sichtbar ist (Google & Cloudflare).\e[0m"
echo -e "\e[1;32m  Du musst nichts weiter tun – einfach warten!\e[0m"
echo -e "\e[1;36m──────────────────────────────────────────────────────\e[0m"
echo ""

# Füge Key zur Checker-Liste hinzu
echo "$CERTBOT_DOMAIN $CERTBOT_VALIDATION" >> /tmp/certbot_check_list.txt

# Beende Hook sofort, damit Certbot weiterläuft bis "Press Enter to Continue"
exit 0
