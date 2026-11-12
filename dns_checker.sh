#!/bin/bash
# Version: 2.0.0
# Dieses Skript wird vom Hauptskript `update_certbot` aufgerufen,
# SOBALD Certbot alle Keys gesammelt hat und auf das finale [ENTER] wartet.
# Es ermittelt automatisch die autoritativen Nameserver der Domain (genau wie Let's Encrypt)
# und gibt sofort nach 3 erfolgreichen Checks in Folge grünes Licht.

exec > /dev/tty 2>&1

CHECK_LIST_FILE="${CHECK_LIST_FILE:-/tmp/certbot_check_list.txt}"
REQUIRED_STREAK=3
CHECK_INTERVAL=5
MAX_CHECKS=360

# Ermittelt alle autoritativen Nameserver für eine Domain (geht bei Subdomains wie www. bis zur Zone-Apex hoch)
get_auth_nameservers() {
    local cur="_acme-challenge.$1"
    local ns_list=""
    while [[ "$cur" == *.* ]]; do
        ns_list=$(dig @8.8.8.8 "$cur" NS +noall +answer +time=2 +tries=1 2>/dev/null | awk '$4 == "NS" {print $5}' | sed 's/\.$//' | sort -u)
        if [ -z "$ns_list" ]; then
            ns_list=$(dig @1.1.1.1 "$cur" NS +noall +answer +time=2 +tries=1 2>/dev/null | awk '$4 == "NS" {print $5}' | sed 's/\.$//' | sort -u)
        fi
        if [ -n "$ns_list" ]; then
            echo "$ns_list" | tr '\n' ' ' | sed 's/ $//'
            return 0
        fi
        cur="${cur#*.}"
    done
    # Fallback auf öffentliche Resolver, falls NS-Ermittlung fehlschlägt
    echo "8.8.8.8 1.1.1.1"
}

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
done < "$CHECK_LIST_FILE"
echo -e "\e[1;36m========================================================\e[0m"
echo "Ermittle zuständige (autoritative) Nameserver und prüfe fortlaufend..."
echo "Sobald $REQUIRED_STREAK Checks in Folge auf allen Nameservern OK melden, wird sofort ausgestellt!"

declare -A checks_count
declare -A streak
declare -A completed
declare -A whitespace_warned
declare -A ns_status_line
declare -A domain_ns_map

# Lese alle Einträge ein und ermittle einmalig die autoritativen Nameserver pro Domain
domains=()
validations=()
while read -r domain validation; do
    if [ -n "$domain" ] && [ -n "$validation" ]; then
        domains+=("$domain")
        validations+=("$validation")
        if [ -z "${domain_ns_map[$domain]}" ]; then
            domain_ns_map["$domain"]="$(get_auth_nameservers "$domain")"
        fi
    fi
done < "$CHECK_LIST_FILE"

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
    echo -e " \e[1;36m$sp [$timestamp] Prüfe autoritative Nameserver... (Aktiv: $active_count, Fertig: $completed_count) \e[1;30m[$status_info]\e[0m"
    
    # Details pro Domain
    for idx in "${!domains[@]}"; do
        local domain="${domains[$idx]}"
        local validation="${validations[$idx]}"
        local val_short="${validation:0:8}..."
        
        if [ -n "${completed[$validation]}" ]; then
            local count=${checks_count[$validation]:-0}
            echo -e "  \e[1;32m✅ _acme-challenge.$domain (Wert: $val_short): VERIFIZIERT (${REQUIRED_STREAK}/${REQUIRED_STREAK} OK nach $count Checks)\e[0m"
        else
            local count=${checks_count[$validation]:-0}
            local cur_streak=${streak[$validation]:-0}
            local status_str=${ns_status_line[$validation]:-"\e[1;30mWARTE...\e[0m"}
            echo -e "  \e[1;33m⏳ _acme-challenge.$domain (Wert: $val_short): $status_str (OK-Serie: ${cur_streak}/${REQUIRED_STREAK}, Check $count)\e[0m"
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
            
            ns_servers=(${domain_ns_map["$domain"]})
            all_ns_ok=true
            has_whitespace=false
            line_parts=()
            
            for ns in "${ns_servers[@]}"; do
                RAW=$(dig @"$ns" TXT "_acme-challenge.$domain" +short +norecurse +time=2 +tries=1 2>/dev/null)
                FOUND=$(echo "$RAW" | grep -Fx -e "\"$validation\"")
                SUB=$(echo "$RAW" | grep -F -e "$validation")
                
                if [ -n "$FOUND" ]; then
                    line_parts+=("$ns [\e[1;32mOK\e[0m]")
                elif [ -n "$SUB" ]; then
                    line_parts+=("$ns [\e[1;33mLEERZEICHEN!\e[0m]")
                    all_ns_ok=false
                    has_whitespace=true
                else
                    line_parts+=("$ns [\e[1;31mFEHLT\e[0m]")
                    all_ns_ok=false
                fi
            done
            
            # Baue Status-Zeile für alle Nameserver dieser Domain zusammen
            joined_status=""
            for part in "${line_parts[@]}"; do
                if [ -z "$joined_status" ]; then
                    joined_status="$part"
                else
                    joined_status="$joined_status | $part"
                fi
            done
            ns_status_line["$validation"]="$joined_status"

            # Einmalige sofortige Warnung ausgeben, falls ein Leerzeichen im TXT-Record erkannt wurde
            if [ "$has_whitespace" = true ] && [ -z "${whitespace_warned[$validation]}" ]; then
                val_short="${validation:0:8}..."
                perm_messages+=("\e[1;31m⚠ ACHTUNG: Der TXT-Eintrag für '_acme-challenge.$domain' (Wert: $val_short) enthält führende oder nachgestellte Leerzeichen!\e[0m")
                perm_messages+=("\e[1;33m  Bitte entferne das Leerzeichen jetzt direkt bei deinem DNS-Provider (das Skript wartet automatisch weiter).\e[0m")
                whitespace_warned[$validation]=1
            fi
            
            count=${checks_count[$validation]:-0}
            new_count=$((count + 1))
            checks_count[$validation]=$new_count
            
            # Zähle aufeinanderfolgende erfolgreiche Checks (alle autoritativen NS müssen gleichzeitig OK sein)
            if [ "$all_ns_ok" = true ]; then
                cur_streak=${streak[$validation]:-0}
                cur_streak=$((cur_streak + 1))
                streak[$validation]=$cur_streak
            else
                streak[$validation]=0
                cur_streak=0
            fi
            
            # Sobald REQUIRED_STREAK (3) Checks in Folge auf allen Nameservern OK sind -> Sofort fertig!
            if [ "$cur_streak" -ge "$REQUIRED_STREAK" ]; then
                perm_messages+=("\e[1;32m[+] VERIFIZIERT (${REQUIRED_STREAK}/${REQUIRED_STREAK} Checks auf allen Nameservern OK): _acme-challenge.$domain -> $validation\e[0m")
                completed[$validation]=1
                continue
            fi
            
            # Hinweis bei längerer Wartezeit (nach 120 Checks / ca. 10 Min.)
            if [ "$new_count" -eq 120 ]; then
                val_short="${validation:0:8}..."
                perm_messages+=("\e[1;33m⚠ HINWEIS: Der Eintrag für '_acme-challenge.$domain' (Wert: $val_short) ist seit ca. 10 Minuten noch nicht sichtbar.\e[0m")
                perm_messages+=("\e[1;33m  Bitte prüfe, ob du bei deinem Provider auf 'Update'/'Speichern' geklickt hast (das Skript wartet weiter).\e[0m")
            fi
            
            # Sicherheits-Timeout erst nach MAX_CHECKS (360 Checks = ca. 30-35 Min.)
            if [ "$new_count" -ge "$MAX_CHECKS" ]; then
                if [ "$is_first_iteration" = false ]; then
                    echo -ne "\e[${BLOCK_HEIGHT}A\e[J"
                fi
                for msg in "${perm_messages[@]}"; do
                    echo -e "$msg"
                done
                echo -e "\n\e[1;31m❌ FEHLER: Maximale Wartezeit ($MAX_CHECKS Prüfungen) für '_acme-challenge.$domain' überschritten!\e[0m"
                echo -e "\e[1;31mProzess abgebrochen. Bitte korrigiere die DNS-Einträge und starte das Skript neu.\e[0m"
                exit 3
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
        
        echo -e "\e[1;35m>>> ALLE KEYS WURDEN AUF DEN AUTORITATIVEN NAMESERVERN VERIFIZIERT! <<<\e[0m"
        echo -n "Starte Zertifikatsausstellung in 3 Sekunden "
        for i in {1..3}; do
            echo -n "."
            sleep 1
        done
        echo -e "\n\e[1;32mGebe grünes Licht an Certbot für die Ausstellung...\e[0m"
        exit 0
    else
        # 5 Sekunden Wartezeit zwischen den Checks mit sekündlicher Aktualisierung
        for ((s=CHECK_INTERVAL; s>=1; s--)); do
            sleep 1
            spinner_idx=$((spinner_idx + 1))
            sp="${spinner[$((spinner_idx % ${#spinner[@]}))]}"
            current_time=$(date "+%H:%M:%S")
            draw_ui "$sp" "$current_time" "Nächster Check in ${s}s"
        done
    fi
done
