#!/usr/bin/env bash

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=${SCRIPT%/*}
PROJECT_DIR=$(readlink -f "${SCRIPT_DIR}/..")

cd "$SCRIPT_DIR"

set -a
source "$PROJECT_DIR/.env"
set +a

if [[ -z "$GROUP"  || -z "$VM_ID_FILE"  || -z "$LAB_USER"  || -z "$LAB_PASSWD" ]]; then
  echo "The file .env or the environment needs to contain settings, see README.md"
  exit 1
fi

set -e     # exit script if a command fails

for IP in $(hcloud server list -l "group=${GROUP}" -o columns=ipv4 -o noheader); do
  (
    scp -i "${VM_ID_FILE}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "${PROJECT_DIR}"/vm-scripts/* "root@${IP}:" \
    && ssh -i "${VM_ID_FILE}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -n "root@${IP}" ./initialize.sh \
    && ssh -i "${VM_ID_FILE}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -n "root@${IP}" ./create_user.sh "${LAB_USER}" "${LAB_PASSWD}"
  ) &
done

wait
