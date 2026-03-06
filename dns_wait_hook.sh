#!/bin/bash
# Version: 1.0 (Sequentielle Version / Lösung C)
exec > /dev/tty 2>&1

echo -e "\e[1;33m>>> SCHLÜSSEL GEFORDERT <<<\e[0m"
echo "Bitte folgenden TXT-Eintrag im DNS hinterlegen:"
echo -e "Host: \e[1;36m_acme-challenge.$CERTBOT_DOMAIN\e[0m"
echo -e "Wert: \e[1;36m$CERTBOT_VALIDATION\e[0m"
echo "--------------------------------------------------------"
echo ""

# Füge Key zur Liste hinzu (Für den Checker relevant)
echo "$CERTBOT_DOMAIN $CERTBOT_VALIDATION" >> /tmp/certbot_check_list.txt

# Beende Hook sofort, damit Certbot weiterläuft bis "Press Enter to Continue"
exit 0
