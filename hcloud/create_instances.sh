#!/usr/bin/env bash

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=${SCRIPT%/*}
PROJECT_DIR=$(readlink -f "${SCRIPT_DIR}/..")

cd "$SCRIPT_DIR"

set -a
source "$PROJECT_DIR/.env"
set +a

if [[ ! -f "$VM_ID_FILE" ]]; then
  echo "creating ssh key"
  ssh-keygen -t ed25519 -N "" -f "$VM_ID_FILE"
fi

FINGERPRINT="$(ssh-keygen -lf "$VM_ID_FILE" -E md5 | awk '{print $2}' | cut -d: -f2-)"
SSH_KEY_NAME="$(hcloud ssh-key list -o columns=name,fingerprint -o noheader | grep -i "$FINGERPRINT" | cut -d' ' -f1)"
if [[ -z "$SSH_KEY_NAME" ]]; then
  echo "uploading ssh public key"
  hcloud ssh-key create \
        --name "${GROUP}-ssh-$(basename "${VM_ID_FILE}")" \
        --public-key-from-file "${VM_ID_FILE}.pub" \
        --label "group=${GROUP}"
  SSH_KEY_NAME="${GROUP}-ssh-$(basename "${VM_ID_FILE}")"
fi

NUM_VMS=${1:-$NUM_VMS}
if [[ -n "$NUM_VMS" ]]; then
  VM_NAMES_NUM=$(seq -f "${GROUP}-%g" "$NUM_VMS")
fi

if [[ -n "$VM_NAMES_FILE" ]]; then
  VM_NAMES_PLAIN=$(cat "$VM_NAMES_FILE")
fi

for VM_NAME in $VM_NAMES_NUM $VM_NAMES_PLAIN; do
  echo "Create instance '${VM_NAME}'"

  hcloud server create \
      --type "${SERVERTYPE:-cx31}" \
      --image "${IMAGE:-ubuntu-22.04}" \
      --datacenter "${DATACENTER:-nbg1-dc3}" \
      --label "group=${GROUP}" \
      --name "${VM_NAME}" \
      --ssh-key "${SSH_KEY_NAME}" &
done

wait

for IP in $(hcloud server list -l "group=${GROUP}" -o columns=ipv4 -o noheader); do
  echo "wait until $IP responds on port 22..."
  while ! nc -zv "$IP" 22; do
    sleep 1
  done
done
