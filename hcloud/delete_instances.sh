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

set -e     # exit script if a command fails

for VM_HOSTNAME in $(hcloud server list -l "group=${settings_group}" -o columns=name -o noheader); do
  echo "Delete instance '${VM_HOSTNAME}'"
  hcloud server delete "$VM_HOSTNAME" &
done

wait
