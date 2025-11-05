#!/usr/bin/env bash

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=${SCRIPT%/*}
PROJECT_DIR=$(readlink -f "${SCRIPT_DIR}/..")

cd "$SCRIPT_DIR" || exit
SETTINGS_FILE="${PROJECT_DIR}/settings.yaml"

set -a
# shellcheck disable=SC1090
source <(yq -o=shell "${SETTINGS_FILE}" | sed "/\\\$/s/'//g")
set +a

printf "\nDelete DNS records for group '${settings_group}'\n"
ZONE_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=nerdapp.work" \
               -H "Authorization: Bearer ${settings_cloudflare_api_token}" \
               -H "Content-Type: application/json" \
          | yq -oy '.result[0].id')

DNS=$(curl -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?comment=group+${settings_group}" \
           -H "Authorization: Bearer ${settings_cloudflare_api_token}" \
           -H "Content-Type: application/json" \
        | yq -oy '.result[].id')

for DNS_ID in $DNS; do
  curl -X DELETE -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${DNS_ID}" \
       -H "Authorization: Bearer ${settings_cloudflare_api_token}" > /dev/null
done
