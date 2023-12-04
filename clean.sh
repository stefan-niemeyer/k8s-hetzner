#!/usr/bin/env bash

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=${SCRIPT%/*}
PROJECT_DIR=$(readlink -f "${SCRIPT_DIR}")

cd "$SCRIPT_DIR"

set -a
source "$PROJECT_DIR/.env"
set +a

set -e     # exit script if a command fails

"${PROJECT_DIR}/dns/delete_dns_records.sh"

"${PROJECT_DIR}/hcloud/delete_instances.sh"
