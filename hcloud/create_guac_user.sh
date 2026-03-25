#!/usr/bin/env bash

echo "🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶 ${0##*/} 🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶"

GUAC_URL="https://ssh.nerdapp.work/guacamole"
ADMIN_USER="$1"
ADMIN_PASS="$2"

GUAC_USER="$3"
GUAC_PASS="$4"

# VM data
VM_NAME="${GUAC_USER}@nerdapp.work"
VM_IP="${GUAC_USER}.nerdapp.work"
VM_SSH_USER="${GUAC_USER}"
VM_SSH_PASS="${GUAC_PASS}"

echo "1. get authentication token..."
TOKEN=$(curl -ks -X POST "${GUAC_URL}/api/tokens" \
  -d "username=$ADMIN_USER&password=${ADMIN_PASS}" | jq -r '.authToken')

if [ "${TOKEN}" == "null" ] || [ -z "${TOKEN}" ]; then
    echo "Error during login. Check credentials!" >&2
    exit 1
fi

echo "2. create Guacamole user (${GUAC_USER})..."
curl -ks -X POST "${GUAC_URL}/api/session/data/postgresql/users?token=${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "'"${GUAC_USER}"'",
    "password": "'"${GUAC_PASS}"'",
    "attributes": {}
  }' > /dev/null

echo "3. create SSH connection (${VM_NAME})..."
CONN_RESPONSE=$(curl -ks -X POST "${GUAC_URL}/api/session/data/postgresql/connections?token=${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "parentIdentifier": "ROOT",
    "name": "'"${VM_NAME}"'",
    "protocol": "ssh",
    "parameters": {
      "hostname": "'"${VM_IP}"'",
      "port": "22",
      "username": "'"${VM_SSH_USER}"'",
      "password": "'"${VM_SSH_PASS}"'"
    },
    "attributes": {}
  }')
echo "CONN_RESPONSE=${CONN_RESPONSE}"
# Get the ID of the created connection
CONN_ID=$(echo "${CONN_RESPONSE}" | jq -r '.identifier')

if [ "$CONN_ID" == "null" ]; then
    echo "Error during creation of connection." >&2
    exit 1
fi
echo "-> Connection created with ID: ${CONN_ID}"

echo "4. Grant rights (user may use connection)..."
curl -k -X PATCH "${GUAC_URL}/api/session/data/postgresql/users/${GUAC_USER}/permissions?token=${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "op": "add",
      "path": "/connectionPermissions/'"${CONN_ID}"'",
      "value": "READ"
    }
  ]'

echo "DONE"
