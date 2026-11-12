#!/bin/bash
# Version: 2.0.0 (Sequentielle Version / Fest eingestellt auf Root + www)
exec > /dev/tty 2>&1

WORK_DIR="${WORK_DIR:-/tmp}"
CHECK_LIST_FILE="${CHECK_LIST_FILE:-/tmp/certbot_check_list.txt}"

# Zähle die beiden Schlüssel (#1 für domain.de und #2 für www.domain.de) pro Durchlauf
COUNTER_FILE="$WORK_DIR/certbot_hook_counter"
if [ -f "$COUNTER_FILE" ]; then
    COUNT=$(cat "$COUNTER_FILE")
    COUNT=$((COUNT + 1))
else
    COUNT=1
fi
echo "$COUNT" > "$COUNTER_FILE"

echo ""
echo -e "\e[1;44m                                                        \e[0m"
echo -e "\e[1;44m   DNS-EINTRAG #${COUNT} VON 2 ERFORDERLICH                    \e[0m"
echo -e "\e[1;44m                                                        \e[0m"
echo ""
echo -e "Certbot braucht einen TXT-Eintrag für \e[1;36m${CERTBOT_DOMAIN}\e[0m:"
echo ""
echo -e "\e[1;33m┌─────────────────────────────────────────────────────┐\e[0m"
echo -e "\e[1;33m│  Eintrag #${COUNT} bei deinem DNS-Provider (Host Europe):  │\e[0m"
echo -e "\e[1;33m└─────────────────────────────────────────────────────┘\e[0m"
echo ""
echo -e "  Typ      :  \e[1;32mTXT\e[0m"
echo -e "  Hostname :  \e[1;32m_acme-challenge.${CERTBOT_DOMAIN}\e[0m"
echo -e "  Wert     :  \e[1;35m${CERTBOT_VALIDATION}\e[0m"
echo ""

if [ "$COUNT" -eq 2 ]; then
    echo -e "\e[1;36m──────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;32m  Beide Codes (#1 ohne www & #2 mit www) liegen nun vor!\e[0m"
    echo -e "\e[1;32m  Trage beide Werte ohne Leerzeichen bei Host Europe ein\e[0m"
    echo -e "\e[1;32m  und klicke jeweils unter dem Feld auf 'Update'.\e[0m"
    echo -e "\e[1;32m  Sobald 3 Checks in Folge OK sind, wird sofort ausgestellt!\e[0m"
    echo -e "\e[1;36m──────────────────────────────────────────────────────\e[0m"
    echo ""
fi

# Füge Key zur Checker-Liste hinzu
echo "$CERTBOT_DOMAIN $CERTBOT_VALIDATION" >> "$CHECK_LIST_FILE"

# Beende Hook sofort, damit Certbot weiterläuft bis "Press Enter to Continue"
exit 0
