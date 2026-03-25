#!/usr/bin/env bash

echo "🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶 ${0##*/} 🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶"

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=${SCRIPT%/*}
PROJECT_DIR=$(readlink -f "${SCRIPT_DIR}/..")
GUAC_SCRIPTS_DIR=$(readlink -f "${PROJECT_DIR}/guacamole-scripts")
WORKER_SCRIPTS_DIR=$(readlink -f "${PROJECT_DIR}/worker-scripts")

cd "${SCRIPT_DIR}" || exit
SETTINGS_FILE="${PROJECT_DIR}/settings.yaml"

set -a
# shellcheck disable=SC1090
source <(yq -o=shell "${SETTINGS_FILE}" | sed "/\\\$/s/'//g")
set +a

if [[ -z "$settings_group"  || -z "$settings_vm_id_file"  || -z "$settings_lab_user"  || -z "$settings_lab_passwd" ]]; then
  echo "The file '${SETTINGS_FILE##*/}' needs to contain settings, see README.md" >&2
  exit 1
fi

set -e     # exit script if a command fails

settings_guacamole_selector=${settings_guacamole_selector:-usage=guacamole}
SERVER_LIST=$(hcloud server list -l "group=${settings_group}" -l "${settings_guacamole_selector}" -o columns=name,ipv4 -o noheader)
GUAC_SERVER="ssh.nerdapp.work"
while read -r SERVER_INFOS; do
    IFS=' ' read -r VM_HOSTNAME PUBLIC_IP <<< "${SERVER_INFOS}"
    scp -i "${settings_vm_id_file}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "${GUAC_SCRIPTS_DIR}"/* "root@${PUBLIC_IP}:"
    ssh -i "${settings_vm_id_file}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -n "root@${PUBLIC_IP}" ./initialize.sh "${settings_guac_admin}" "${settings_guac_passwd}" "${settings_cloudflare_api_token}" "${settings_cloudflare_email}"
    if [[ ! -f "${GUAC_SCRIPTS_DIR}/fullchain.pem" ]] || [[ ! -f "${GUAC_SCRIPTS_DIR}/privkey.pem" ]]; then
        scp -i "${settings_vm_id_file}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "root@${PUBLIC_IP}:/etc/letsencrypt/live/nerdapp.work/fullchain.pem" "${GUAC_SCRIPTS_DIR}"
        scp -i "${settings_vm_id_file}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "root@${PUBLIC_IP}:/etc/letsencrypt/live/nerdapp.work/privkey.pem" "${GUAC_SCRIPTS_DIR}"
        kubectl create secret tls nerdapp-work-tls --cert "${GUAC_SCRIPTS_DIR}/fullchain.pem" --key "${GUAC_SCRIPTS_DIR}/privkey.pem" --dry-run=client -o yaml > "${WORKER_SCRIPTS_DIR}/nerdapp-work-tls.yaml"
    fi
    echo "wait until ${GUAC_SERVER} responds on port 443..."
    sleep 10
    while ! nc -zv "${PUBLIC_IP}" 443; do
        sleep 5
    done
done <<< "${SERVER_LIST}"
