#!/usr/bin/env bash

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=${SCRIPT%/*}
PROJECT_DIR=$(readlink -f "${SCRIPT_DIR}/..")

cd "$SCRIPT_DIR"

set -a
source "$PROJECT_DIR/.env"
set +a

set -e     # exit script if a command fails

for VM_NAME in $(hcloud server list -l "group=${GROUP}" -o columns=name -o noheader); do
  echo "Delete instance '${VM_NAME}'"
  hcloud server delete "$VM_NAME" &
done

wait
