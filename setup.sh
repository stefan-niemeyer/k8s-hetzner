#!/usr/bin/env bash

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=${SCRIPT%/*}
PROJECT_DIR=$(readlink -f "${SCRIPT_DIR}")

cd "$SCRIPT_DIR"

set -a
source "$PROJECT_DIR/.env"
set +a

"${PROJECT_DIR}/hcloud/create_instances.sh" "$1"
"${PROJECT_DIR}/hcloud/setup_instances.sh"
"${PROJECT_DIR}/dns/create_dns_records.sh"
