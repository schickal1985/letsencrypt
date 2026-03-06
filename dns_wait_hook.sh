#!/bin/bash
# Version: 1.0 (Parallel Background Jobs)
# Wird von den unsichtbaren Background-Certbots aufgerufen.
# Gibt keinen Text an den User aus, sondern loggt nur den Key.

echo "$CERTBOT_DOMAIN $CERTBOT_VALIDATION" >> /tmp/certbot_check_list.txt

# Beende Hook sofort, damit Certbot weiterläuft bis "Press Enter to Continue"
exit 0
