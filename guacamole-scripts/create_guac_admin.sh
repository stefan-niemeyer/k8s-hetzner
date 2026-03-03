#!/usr/bin/env bash

echo "🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶 ${0##*/} 🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶"

GUAC_URL="http://localhost:8080/guacamole"
ADMIN_USER="guacadmin"
ADMIN_PASS="guacadmin"

NEW_ADMIN_USER="$1"
NEW_ADMIN_PASS="$2"

# 1. Get token for old admin
TOKEN=$(curl -s -X POST "$GUAC_URL/api/tokens" \
  -d "username=${ADMIN_USER}&password=${ADMIN_PASS}" | jq -r '.authToken')

echo "Create new account..."
curl -s -X POST "$GUAC_URL/api/session/data/postgresql/users?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "'"${NEW_ADMIN_USER}"'",
    "password": "'"${NEW_ADMIN_PASS}"'",
    "attributes": {}
  }' > /dev/null

echo "Grant global admin rights to new account..."
# The right "ADMINISTER" grants full access to the system
curl -s -X PATCH "${GUAC_URL}/api/session/data/postgresql/users/${NEW_ADMIN_USER}/permissions?token=${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "op": "add",
      "path": "/systemPermissions",
      "value": "ADMINISTER"
    }
  ]' > /dev/null

echo "Delete standard admin account..."
NEW_TOKEN=$(curl -s -X POST "$GUAC_URL/api/tokens" \
  -d "username=${NEW_ADMIN_USER}&password=${NEW_ADMIN_PASS}" | jq -r '.authToken')
curl -s -X DELETE "${GUAC_URL}/api/session/data/postgresql/users/${ADMIN_USER}?token=${NEW_TOKEN}" > /dev/null

echo "Done! The new admin is '${NEW_ADMIN_USER}'"
