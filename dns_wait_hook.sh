#!/bin/bash
# Version: 0.9
exec > /dev/tty 2>&1

echo -e "\e[1;33m>>> SCHLÜSSEL GEFORDERT <<<\e[0m"
echo -e "Bitte folgenden TXT-Eintrag im DNS hinterlegen:"
echo -e "Host: \e[1;36m_acme-challenge.$CERTBOT_DOMAIN\e[0m"
echo -e "Wert: \e[1;36m$CERTBOT_VALIDATION\e[0m"
echo -e "--------------------------------------------------------\n"

# Wir sichern den Eintrag für unser Checker-Skript im Puffer
echo "_acme-challenge.$CERTBOT_DOMAIN $CERTBOT_VALIDATION" >> /tmp/certbot_check_list.txt

# WICHTIG: Kein Sleep oder Warten mehr! 
# Wir beenden diesen Hook sofort, damit Certbot beim 2., 3., 4. Key 
# sofort weitermacht und dir alle Keys am Stück listet!
exit 0
