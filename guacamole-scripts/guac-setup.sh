#!/usr/bin/env bash

set -e

echo "🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶 ${0##*/} 🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶"

export PG_PASSWORD=$(uuid)
/usr/bin/envsubst '$PG_PASSWORD' < docker-compose.template.yml > docker-compose.yml

echo "1. Create folder for DB initialization..."
mkdir -p ./initdb

echo "2. Generate the initdb.sql schema directly from the Guacamole image..."
# we generate the scheme and put it in a folder we will mount to PostgreSQL
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql > ./initdb/initdb.sql

echo "3. Start Docker Compose in the background..."
docker compose up -d --wait

echo "DONE! PostgreSQL is initialized and Guacamole is ready."
