#!/bin/bash
# Version: 1.6 (Sequentielle Version / Lösung C)
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
echo -e "\e[1;33m========================================================\e[0m"
echo -e "\e[1;33m  SCHLÜSSEL #${COUNT} GEFORDERT für: ${CERTBOT_DOMAIN}\e[0m"
echo -e "\e[1;33m========================================================\e[0m"
echo ""
echo -e "Bitte trage folgenden TXT-Eintrag bei deinem DNS-Provider ein:"
echo ""
echo -e "  Hostname : \e[1;36m_acme-challenge.${CERTBOT_DOMAIN}\e[0m"
echo -e "  Typ      : \e[1;36mTXT\e[0m"
echo -e "  Wert     : \e[1;35m${CERTBOT_VALIDATION}\e[0m"
echo ""

if [ "$COUNT" -eq 1 ]; then
    echo -e "\e[1;33mHINWEIS: Falls ein 2. Schlüssel folgt - NICHT den ersten überschreiben!\e[0m"
    echo -e "         Klicke bei deinem Provider auf 'Hinzufügen' (nicht 'Update')."
fi

echo -e "\e[1;33m========================================================\e[0m"
echo ""

# Füge Key zur Checker-Liste hinzu
echo "$CERTBOT_DOMAIN $CERTBOT_VALIDATION" >> /tmp/certbot_check_list.txt

# Beende Hook sofort, damit Certbot weiterläuft bis "Press Enter to Continue"
exit 0
