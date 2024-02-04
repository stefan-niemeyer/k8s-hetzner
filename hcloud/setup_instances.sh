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

if [[ -z "$settings_group"  || -z "$settings_vm_id_file"  || -z "$settings_lab_user"  || -z "$settings_lab_passwd" ]]; then
  echo "The file '${SETTINGS_FILE##*/}' needs to contain settings, see README.md"
  exit 1
fi

set -e     # exit script if a command fails

SERVER_LIST=$(hcloud server list -l "group=${settings_group}" -o columns=name,ipv4 -o noheader)
while read -r SERVER_INFOS; do
  IFS=' ' read -r VM_HOSTNAME PUBLIC_IP <<< "${SERVER_INFOS}"
  declare -a VM_USERS
  VM_USERS=( $(yq eval '.vm[].servers[] | select(.name == "'"${VM_HOSTNAME}"'").users[].name' "${SETTINGS_FILE}") )
  if [[ -z "$users" ]]; then
    VM_USERS+=( "${settings_lab_user}" )
  fi

  (
    scp -i "${settings_vm_id_file}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "${PROJECT_DIR}"/vm-scripts/* "root@${PUBLIC_IP}:" \
    && ssh -i "${settings_vm_id_file}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -n "root@${PUBLIC_IP}" ./initialize.sh \
    && for VM_USER in "${VM_USERS[@]}"; do
         printf "Setup instance %-20s for user %s\n" "'${VM_HOSTNAME}'" "'${VM_USER}'"
         if [[ "${VM_USER}" == "${settings_lab_user}" ]]; then
           HOST_ALIAS="${VM_HOSTNAME}"
         else
           HOST_ALIAS="${VM_USER}"
         fi

         ssh -i "${settings_vm_id_file}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -n "root@${PUBLIC_IP}" ./create_user.sh "${HOST_ALIAS}" "${VM_USER}" "${settings_lab_passwd}"
       done
  ) &
done <<< "${SERVER_LIST}"

wait
