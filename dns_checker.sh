#!/bin/bash
# Version: 1.7
# Dieses Skript wird vom głównen `update_certbot` Wrapper aufgerufen, 
# SOBALD Certbot alle Keys gesammelt hat und auf das finale [ENTER] wartet.

exec > /dev/tty 2>&1

echo -e "\e[1;36m========================================================\e[0m"
echo -e "\e[1;36m BITTE TRAGE FOLGENDE DNS-TXT-EINTRÄGE BEI DEINEM PROVIDER EIN:\e[0m"
echo -e "\e[1;36m========================================================\e[0m"
idx=1
while read -r domain validation; do
    echo -e "  \e[1;37mEintrag #$idx:\e[0m"
    echo -e "    Typ:      \e[1;32mTXT\e[0m"
    echo -e "    Hostname: \e[1;32m_acme-challenge.$domain\e[0m"
    echo -e "    Wert:     \e[1;35m$validation\e[0m"
    echo ""
    idx=$((idx + 1))
done < /tmp/certbot_check_list.txt
echo -e "\e[1;36m========================================================\e[0m"
echo "Das Skript prüft nun fortlaufend alle geforderten Einträge parallel."

# Speichert den Verlauf (0=Fehler, 1=Erfolg) der letzten 10 Checks pro Key
declare -A history_g
declare -A history_c
declare -A history_o
declare -A checks_count
declare -A completed
declare -A google_status
declare -A cloudflare_status
declare -A opendns_status

# Lese alle Einträge ein
domains=()
validations=()
while read -r domain validation; do
    if [ -n "$domain" ] && [ -n "$validation" ]; then
        domains+=("$domain")
        validations+=("$validation")
    fi
done < /tmp/certbot_check_list.txt

NUM_ENTRIES=${#domains[@]}
BLOCK_HEIGHT=$((NUM_ENTRIES + 1))

# Spinner-Frames für die Sanduhr-Animation
spinner=("⏳" "⌛")
spinner_idx=0
is_first_iteration=true

# Warteschlange für dauerhafte Ausgaben (scrollen nach oben)
perm_messages=()

draw_ui() {
    local sp="$1"
    local timestamp="$2"
    local status_info="$3"
    
    # Falls nicht der erste Durchlauf, schiebe Cursor nach oben und lösche alles darunter
    if [ "$is_first_iteration" = false ]; then
        echo -ne "\e[${BLOCK_HEIGHT}A\e[J"
    fi
    
    # Gib ausstehende dauerhafte Nachrichten aus
    if [ ${#perm_messages[@]} -gt 0 ]; then
        for msg in "${perm_messages[@]}"; do
            echo -e "$msg"
        done
        perm_messages=()
    fi
    
    # Berechne Zähler
    local active_count=0
    local completed_count=0
    for val in "${validations[@]}"; do
        if [ -n "${completed[$val]}" ]; then
            completed_count=$((completed_count + 1))
        else
            active_count=$((active_count + 1))
        fi
    done
    
    # Header Zeile
    echo -e " \e[1;36m$sp [$timestamp] Prüfe DNS-Propagation... (Aktiv: $active_count, Stabil: $completed_count) \e[1;30m[$status_info]\e[0m"
    
    # Details pro Domain
    for idx in "${!domains[@]}"; do
        local domain="${domains[$idx]}"
        local validation="${validations[$idx]}"
        local val_short="${validation:0:8}..."
        
        if [ -n "${completed[$validation]}" ]; then
            local count=${checks_count[$validation]:-0}
            echo -e "  \e[1;32m✅ _acme-challenge.$domain (Wert: $val_short): STABIL GEFUNDEN (nach $count Checks)\e[0m"
        else
            local count=${checks_count[$validation]:-0}
            local g_stat=${google_status[$validation]:-"\e[1;30mWARTE\e[0m"}
            local c_stat=${cloudflare_status[$validation]:-"\e[1;30mWARTE\e[0m"}
            local o_stat=${opendns_status[$validation]:-"\e[1;30mWARTE\e[0m"}
            echo -e "  \e[1;33m⏳ _acme-challenge.$domain (Wert: $val_short): Google [$g_stat] | Cloudflare [$c_stat] | OpenDNS [$o_stat] (Check $count/90)\e[0m"
        fi
    done
    
    is_first_iteration=false
}

while true; do
    all_done=true
    TIMESTAMP=$(date "+%H:%M:%S")
    sp="${spinner[$((spinner_idx % ${#spinner[@]}))]}"
    
    # UI zeichnen vor den DNS-Abfragen (zeigt "Prüfe..." an)
    draw_ui "$sp" "$TIMESTAMP" "Prüfe..."
    
    for idx in "${!domains[@]}"; do
        domain="${domains[$idx]}"
        validation="${validations[$idx]}"
        
        if [ -z "${completed[$validation]}" ]; then
            all_done=false
            
            # DNS Abfragen
            G_FOUND=$(dig @8.8.8.8 TXT "_acme-challenge.$domain" +short | grep -F -e "$validation")
            C_FOUND=$(dig @1.1.1.1 TXT "_acme-challenge.$domain" +short | grep -F -e "$validation")
            O_FOUND=$(dig @208.67.222.222 TXT "_acme-challenge.$domain" +short | grep -F -e "$validation")
            
            # Status ermitteln
            if [ -n "$G_FOUND" ]; then google_status[$validation]="\e[1;32mOK\e[0m"; else google_status[$validation]="\e[1;31mFEHLT\e[0m"; fi
            if [ -n "$C_FOUND" ]; then cloudflare_status[$validation]="\e[1;32mOK\e[0m"; else cloudflare_status[$validation]="\e[1;31mFEHLT\e[0m"; fi
            if [ -n "$O_FOUND" ]; then opendns_status[$validation]="\e[1;32mOK\e[0m"; else opendns_status[$validation]="\e[1;31mFEHLT\e[0m"; fi
            
            count=${checks_count[$validation]:-0}
            checks_count[$validation]=$((count + 1))
            new_count=$((count + 1))
            pos=$((count % 10))
            
            # Verlauf speichern
            if [ -n "$G_FOUND" ]; then history_g["$validation,$pos"]=1; else history_g["$validation,$pos"]=0; fi
            if [ -n "$C_FOUND" ]; then history_c["$validation,$pos"]=1; else history_c["$validation,$pos"]=0; fi
            if [ -n "$O_FOUND" ]; then history_o["$validation,$pos"]=1; else history_o["$validation,$pos"]=0; fi
            
            # Warnung bei Verzögerung (nach 60 Checks / ca. 10 Min.)
            if [ "$new_count" -eq 60 ]; then
                val_short="${validation:0:8}..."
                perm_messages+=("\e[1;33m⚠ WARNUNG: Der Eintrag für '_acme-challenge.$domain' (Wert: $val_short) ist seit 10 Minuten (60 Checks) nicht auffindbar!\e[0m")
                perm_messages+=("\e[1;33mBitte prüfe, ob du den Eintrag bei deinem Provider eventuell überschrieben oder nicht korrekt gespeichert hast.\e[0m")
                perm_messages+=("\e[1;33mBei Wildcard-Zertifikaten müssen BEIDE TXT-Einträge gleichzeitig unter dem Namen '_acme-challenge.$domain' aktiv sein!\e[0m")
            fi
            
            # Timeout (nach 90 Checks / ca. 15 Min.)
            if [ "$new_count" -ge 90 ]; then
                if [ "$is_first_iteration" = false ]; then
                    echo -ne "\e[${BLOCK_HEIGHT}A\e[J"
                fi
                for msg in "${perm_messages[@]}"; do
                    echo -e "$msg"
                done
                echo -e "\n\e[1;31m❌ FEHLER: Timeout nach 90 Prüfungen (15 Min.) für '_acme-challenge.$domain' erreicht!\e[0m"
                echo -e "\e[1;31mProzess abgebrochen. Bitte korrigiere die DNS-Einträge und starte das Skript neu.\e[0m"
                exit 3
            fi
            
            # Stabilitätsprüfung
            if [ "$new_count" -ge 10 ]; then
                sum_g=0
                sum_c=0
                sum_o=0
                for i in {0..9}; do
                    sum_g=$((sum_g + ${history_g["$validation,$i"]:-0}))
                    sum_c=$((sum_c + ${history_c["$validation,$i"]:-0}))
                    sum_o=$((sum_o + ${history_o["$validation,$i"]:-0}))
                done
                
                if [ "$sum_g" -ge 9 ] && [ "$sum_c" -ge 9 ] && [ "$sum_o" -ge 9 ]; then
                    perm_messages+=("\e[1;32m[+] STABIL GEFUNDEN (>=90%): $domain -> $validation\e[0m")
                    completed[$validation]=1
                fi
            fi
        fi
    done
    
    if $all_done; then
        # Bereinige die UI vor der finalen Meldung
        if [ "$is_first_iteration" = false ]; then
            echo -ne "\e[${BLOCK_HEIGHT}A\e[J"
        fi
        for msg in "${perm_messages[@]}"; do
            echo -e "$msg"
        done
        
        echo -e "\e[1;35m>>> ALLE KEYS WURDEN WELTWEIT VERIFIZIERT! <<<\e[0m"
        echo "Warte noch 20 Sekunden Puffer wegen DNS-Caching..."
        for i in {1..20}; do
            echo -n "#"
            sleep 1
        done
        echo -e "\n\e[1;32mGebe grünes Licht an Certbot für die Ausstellung...\e[0m"
        exit 0
    else
        # 10 Sekunden Wartezeit mit sekündlicher Aktualisierung des Spinners und Countdowns
        for s in {10..1}; do
            sleep 1
            spinner_idx=$((spinner_idx + 1))
            sp="${spinner[$((spinner_idx % ${#spinner[@]}))]}"
            current_time=$(date "+%H:%M:%S")
            draw_ui "$sp" "$current_time" "Nächster Check in ${s}s"
        done
    fi
done
