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

# shellcheck disable=SC2046 disable=SC2154
mkdir -p $(dirname "$settings_vm_id_file")
if [[ ! -f "$settings_vm_id_file" ]]; then
  echo "creating ssh key"
  ssh-keygen -t ed25519 -N "" -f "$settings_vm_id_file"
fi

FINGERPRINT="$(ssh-keygen -lf "${settings_vm_id_file}" -E md5 | awk '{print $2}' | cut -d: -f2-)"
SSH_KEY_NAME="$(hcloud ssh-key list -o columns=name,fingerprint -o noheader | grep -i "$FINGERPRINT" | cut -d' ' -f1)"
if [[ -z "$SSH_KEY_NAME" ]]; then
  echo "uploading ssh public key"
  hcloud ssh-key create \
        --name "${settings_group}-ssh-$(basename "${settings_vm_id_file}")" \
        --public-key-from-file "${settings_vm_id_file}.pub" \
        --label "group=${settings_group}"
  SSH_KEY_NAME="${settings_group}-ssh-$(basename "${settings_vm_id_file}")"
else
  echo "ssh public key already uploaded"
fi

settings_num_vms=${1:-$settings_num_vms}
declare -a VM_NAMES_NUM
if [[ -n "$settings_num_vms" && "$settings_num_vms" != "0" ]]; then
  VM_NAMES_NUM=($(seq -f "${settings_group}-%g" "$settings_num_vms"))
fi

SERVER_NAMES=$(yq eval '.vm[].servers[].name' "${SETTINGS_FILE}")
declare -a VM_NAMES_PLAIN
while read -r SERVER_NAME; do
    VM_NAMES_PLAIN+=( "${SERVER_NAME}" )
done <<< "$SERVER_NAMES"

for VM_HOSTNAME in "${VM_NAMES_NUM[@]}" "${VM_NAMES_PLAIN[@]}"; do
  if [[ -z "${VM_HOSTNAME}" ]]; then
    continue
  fi
  servertype=$(yq eval '.vm[].servers[] | select(.name == "'"${VM_HOSTNAME}"'").type' "${SETTINGS_FILE}")
  if [[ -z "$servertype" || "$servertype" == "null" ]]; then
    servertype=${settings_servertype:-cx31}
  fi
  image=$(yq eval '.vm[].servers[] | select(.name == "'"${VM_HOSTNAME}"'").image' "${SETTINGS_FILE}")
  if [[ -z "$image" || "$image" == "null" ]]; then
    image=${settings_image:-ubuntu-24.04}
  fi

  printf "Create instance %-20s servertype %-8s image %-20s\n" "'${VM_HOSTNAME}'" "'${servertype}'" "'${image}'"
  hcloud server create \
      --type "${servertype:-cpx31}" \
      --image "${settings_image:-ubuntu-24.04}" \
      --location "${settings_location:-fsn1}" \
      --label "group=${settings_group}" \
      --name "${VM_HOSTNAME}" \
      --ssh-key "${SSH_KEY_NAME}" &
done
wait

for PUBLIC_IP in $(hcloud server list -l "group=${settings_group}" -o columns=ipv4 -o noheader); do
  echo "wait until ${PUBLIC_IP} responds on port 22..."
  while ! nc -zv "${PUBLIC_IP}" 22; do
    sleep 1
  done
done
