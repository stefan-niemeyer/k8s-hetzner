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

ZONE_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=laserschwert.io" \
               -H "Authorization: Bearer ${settings_cloudflare_api_token}" \
               -H "Content-Type: application/json" \
          | yq -oy '.result[0].id')

SERVER_LIST=$(hcloud server list -l "group=${settings_group}" -o columns=name,ipv4 -o noheader)

while read -r SERVER_INFOS; do
  IFS=' ' read -r VM_HOSTNAME PUBLIC_IP <<< "${SERVER_INFOS}"
  declare -a VM_USERS
  VM_USERS=( $(yq eval '.vm[].servers[] | select(.name == "'"${VM_HOSTNAME}"'").users[].name' "${SETTINGS_FILE}") )

  for HOST_ALIAS in "${VM_HOSTNAME}" "${VM_USERS[@]}"; do
    printf "\n\nHOST_ALIAS: ${HOST_ALIAS}\n"
    printf "PUBLIC_IP: ${PUBLIC_IP}\n"

    curl --request POST -s \
      "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
      -H "Authorization: Bearer ${settings_cloudflare_api_token}" \
      -H "Content-Type: application/json" \
      --data '{
      "content": "'${PUBLIC_IP}'",
      "name": "'${HOST_ALIAS}'.laserschwert.io",
      "proxied": false,
      "type": "A",
      "comment": "group '${settings_group}'",
      "ttl": 3600
    }' > /dev/null
    curl --request POST -s \
      "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
      -H "Authorization: Bearer ${settings_cloudflare_api_token}" \
      -H "Content-Type: application/json" \
      --data '{
      "content": "'${PUBLIC_IP}'",
      "name": "*.'${HOST_ALIAS}'.laserschwert.io",
      "proxied": false,
      "type": "A",
      "comment": "group '${settings_group}'",
      "ttl": 3600
    }' > /dev/null
  done
done <<< "${SERVER_LIST}"
