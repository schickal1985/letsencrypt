#!/bin/bash
# Version: 0.9
# Dieses Skript wird vom głównen `update_certbot` Wrapper aufgerufen, 
# SOBALD Certbot alle Keys gesammelt hat und auf das finale [ENTER] wartet.

exec > /dev/tty 2>&1

echo -e "\e[1;36m========================================================\e[0m"
echo -e "\e[1;36m ALLE SCHLÜSSEL WURDEN GENERIERT UND OBEN ANGEZEIGT!\e[0m"
echo -e "\e[1;36m Bitte trage nun ALLE Keys in Ruhe bei deinem Provider ein.\e[0m"
echo -e "\e[1;36m========================================================\e[0m"
echo "Das Skript prüft nun fortlaufend alle geforderten Einträge parallel."

declare -A completed
total=$(wc -l < /tmp/certbot_check_list.txt)
echo -e "Erwartete Schlüssel insgesamt: \e[1;33m$total\e[0m\n"

while true; do
    all_done=true
    
    while read -r domain validation; do
        if [ -z "${completed[$validation]}" ]; then
            # Suche den genauen String bei Google und Cloudflare
            G_FOUND=$(dig @8.8.8.8 TXT "_acme-challenge.$domain" +short | grep -F -e "$validation")
            C_FOUND=$(dig @1.1.1.1 TXT "_acme-challenge.$domain" +short | grep -F -e "$validation")
            
            if [ -n "$G_FOUND" ] && [ -n "$C_FOUND" ]; then
                echo -e "\e[1;32m[+] ERFOLGREICH GEFUNDEN: $domain -> $validation\e[0m"
                completed[$validation]=1
            else
                all_done=false
                # Wir geben keinen Output bei Fehlschlag/Warten aus, sonst 
                # müllt der Terminal zu, während der Nutzer noch kopiert.
            fi
        fi
    done < /tmp/certbot_check_list.txt
    
    if $all_done; then
        echo -e "\n\e[1;35m>>> ALLE KEYS WURDEN WELTWEIT VERIFIZIERT! <<<\e[0m"
        echo "Warte noch 20 Sekunden Puffer wegen DNS-Caching..."
        for i in {1..20}; do
            echo -n "#"
            sleep 1
        done
        echo -e "\n\e[1;32mGebe grünes Licht an Certbot für die Ausstellung...\e[0m"
        exit 0
    else
        # Lade-Punkt für optisches Feedback
        echo -n "."
        sleep 10
    fi
done
