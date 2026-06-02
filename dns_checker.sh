#!/bin/bash
# Version: 1.6
# Dieses Skript wird vom głównen `update_certbot` Wrapper aufgerufen, 
# SOBALD Certbot alle Keys gesammelt hat und auf das finale [ENTER] wartet.

exec > /dev/tty 2>&1

echo -e "\e[1;36m========================================================\e[0m"
echo -e "\e[1;36m ALLE SCHLÜSSEL WURDEN GENERIERT UND OBEN ANGEZEIGT!\e[0m"
echo -e "\e[1;36m Bitte trage nun ALLE Keys in Ruhe bei deinem Provider ein.\e[0m"
echo -e "\e[1;36m========================================================\e[0m"
echo "Das Skript prüft nun fortlaufend alle geforderten Einträge parallel."

# Speichert den Verlauf (0=Fehler, 1=Erfolg) der letzten 10 Checks pro Key
declare -A history_g
declare -A history_c
declare -A checks_count
declare -A completed

while true; do
    all_done=true
    TIMESTAMP=$(date "+%H:%M:%S")
    echo -e "\n[$TIMESTAMP] Prüfe DNS-Propagation..."
    
    while read -r domain validation; do
        if [ -z "${completed[$validation]}" ]; then
            all_done=false
            
            # Suche den genauen String bei Google und Cloudflare
            G_FOUND=$(dig @8.8.8.8 TXT "_acme-challenge.$domain" +short | grep -F -e "$validation")
            C_FOUND=$(dig @1.1.1.1 TXT "_acme-challenge.$domain" +short | grep -F -e "$validation")
            
            # Status für die Konsolenausgabe ermitteln
            if [ -n "$G_FOUND" ]; then G_STAT="\e[1;32mOK\e[0m"; else G_STAT="\e[1;31mFEHLT\e[0m"; fi
            if [ -n "$C_FOUND" ]; then C_STAT="\e[1;32mOK\e[0m"; else C_STAT="\e[1;31mFEHLT\e[0m"; fi
            
            # Zeige aktuellen Prüfstatus an
            val_short="${validation:0:8}..."
            count=${checks_count[$validation]:-0}
            echo -e "  - _acme-challenge.$domain (Wert: $val_short): Google [$G_STAT] | Cloudflare [$C_STAT] (Check $((count + 1))/90)"
            
            # Position im Ringpuffer (0 bis 9)
            pos=$((count % 10))
            
            # Ergebnis im Verlauf speichern (1=Gefunden, 0=Nicht gefunden/Falscher Key)
            if [ -n "$G_FOUND" ]; then history_g["$validation,$pos"]=1; else history_g["$validation,$pos"]=0; fi
            if [ -n "$C_FOUND" ]; then history_c["$validation,$pos"]=1; else history_c["$validation,$pos"]=0; fi
            
            # Zähler erhöhen
            checks_count[$validation]=$((count + 1))
            new_count=$((count + 1))
            
            # Warnung bei Verzögerung (nach 60 Prüfungen, ca. 10 Minuten)
            if [ "$new_count" -eq 60 ]; then
                echo -e "\n\e[1;33m⚠ WARNUNG: Der Eintrag für '_acme-challenge.$domain' (Wert: $val_short) ist seit 10 Minuten (60 Checks) nicht auffindbar!\e[0m"
                echo -e "\e[1;33mBitte prüfe, ob du den Eintrag bei deinem Provider eventuell überschrieben oder nicht korrekt gespeichert hast.\e[0m"
                echo -e "\e[1;33mBei Wildcard-Zertifikaten müssen BEIDE TXT-Einträge gleichzeitig unter dem Namen '_acme-challenge.$domain' aktiv sein!\e[0m\n"
            fi
            
            # Timeout (nach 90 Prüfungen, ca. 15 Minuten)
            if [ "$new_count" -ge 90 ]; then
                echo -e "\n\e[1;31m❌ FEHLER: Timeout nach 90 Prüfungen (15 Min.) für '_acme-challenge.$domain' erreicht!\e[0m"
                echo -e "\e[1;31mProzess abgebrochen. Bitte korrigiere die DNS-Einträge und starte das Skript neu.\e[0m"
                exit 3
            fi
            
            # Wenn wir noch keine 10 Checks haben, geben wir noch kein "Erfolgreich"
            if [ "$new_count" -ge 10 ]; then
                # Summe der letzten 10 Ergebnisse berechnen
                sum_g=0
                sum_c=0
                for i in {0..9}; do
                    sum_g=$((sum_g + ${history_g["$validation,$i"]:-0}))
                    sum_c=$((sum_c + ${history_c["$validation,$i"]:-0}))
                done
                
                # Wenn mindestens 90% (9 von 10) auf beiden Servern erfolgreich waren
                if [ "$sum_g" -ge 9 ] && [ "$sum_c" -ge 9 ]; then
                    echo -e "\n\e[1;32m[+] STABIL GEFOUNDEN (>=90%): $domain -> $validation\e[0m"
                    completed[$validation]=1
                fi
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
        sleep 10
    fi
done
