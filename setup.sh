#!/usr/bin/env bash

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=${SCRIPT%/*}
PROJECT_DIR=$(readlink -f "${SCRIPT_DIR}")

cd "$SCRIPT_DIR" || exit
SETTINGS_FILE="${PROJECT_DIR}/settings.yaml"

set -a
# shellcheck disable=SC1090
source <(yq -o=shell "${SETTINGS_FILE}" | sed "/\\\$/s/'//g")
set +a

"${PROJECT_DIR}/hcloud/create_instances.sh" "$1"
"${PROJECT_DIR}/hcloud/setup_instances.sh"
"${PROJECT_DIR}/dns/create_dns_records.sh"
