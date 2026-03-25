#!/usr/bin/env bash
# shellcheck disable=SC2086

echo "🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶 ${0##*/} 🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶"

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=${SCRIPT%/*}
PROJECT_DIR=$(readlink -f "${SCRIPT_DIR}/..")

cd "${SCRIPT_DIR}" || exit
SETTINGS_FILE="${PROJECT_DIR}/settings.yaml"

set -a
# shellcheck disable=SC1090
source <(yq -o=shell "${SETTINGS_FILE}" | sed "/\\\$/s/'//g")
set +a

ZONE_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=nerdapp.work" \
               -H "Authorization: Bearer ${settings_cloudflare_api_token}" \
               -H "Content-Type: application/json" \
          | yq -oy '.result[0].id')

SERVER_LIST=$(hcloud server list -l "group=${settings_group}" -o columns=name,ipv4 -o noheader)

insert_dns_record() {
    local zone="$1"
    local token="$2"
    local pub_ip="$3"
    local host_alias="$4"
    local group="$5"

    curl --request POST -s \
      "https://api.cloudflare.com/client/v4/zones/${zone}/dns_records" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      --data '{
      "content": "'${pub_ip}'",
      "name": "'${host_alias}'.nerdapp.work",
      "proxied": false,
      "type": "A",
      "comment": "group '${group}'",
      "ttl": 300
    }' > /dev/null
}

while read -r SERVER_INFOS; do
  IFS=' ' read -r VM_HOSTNAME PUBLIC_IP <<< "${SERVER_INFOS}"
  declare -a VM_USERS
  VM_USERS=( $(yq eval '.vm[].servers[] | select(.name == "'"${VM_HOSTNAME}"'").users[].name' "${SETTINGS_FILE}") )

  for HOST_ALIAS in "${VM_HOSTNAME}" "${VM_USERS[@]}"; do
    printf "\n\nHOST_ALIAS: %s\n" "${HOST_ALIAS}"
    printf "PUBLIC_IP: %s\n" "${PUBLIC_IP}"

    insert_dns_record "${ZONE_ID}" "${settings_cloudflare_api_token}" "${PUBLIC_IP}" "${HOST_ALIAS}" "${settings_group}"
    insert_dns_record "${ZONE_ID}" "${settings_cloudflare_api_token}" "${PUBLIC_IP}" "*.${HOST_ALIAS}" "${settings_group}"
    insert_dns_record "${ZONE_ID}" "${settings_cloudflare_api_token}" "${PUBLIC_IP}" "vx-${HOST_ALIAS}" "${settings_group}"
    insert_dns_record "${ZONE_ID}" "${settings_cloudflare_api_token}" "${PUBLIC_IP}" "blue-green-${HOST_ALIAS}" "${settings_group}"
    insert_dns_record "${ZONE_ID}" "${settings_cloudflare_api_token}" "${PUBLIC_IP}" "canary-${HOST_ALIAS}" "${settings_group}"
  done
done <<< "${SERVER_LIST}"
