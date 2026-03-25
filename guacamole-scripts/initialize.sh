#!/usr/bin/env bash

echo "🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶 ${0##*/} 🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶"

NEW_ADMIN_USER="$1"
NEW_ADMIN_PASS="$2"
CLOUDFLARE_API_TOKEN="$3"
CLOUDFLARE_EMAIL="$4"

# Allow login w/ passwd
#sed --in-place 's/^#?PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
#systemctl reload ssh

echo "Remove old docker versions and update system"
apt-get update -qq && apt-get upgrade -y -qq
apt-get remove -qq docker docker-engine docker.io containerd runc

echo "Install dependencies and GPG key"
apt-get install -y -qq ca-certificates curl gnupg lsb-release uuid jq
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "Add Docker as apt source"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Install Docker Engine and Compose"
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

# start Guacamole
./guac-setup.sh
sleep 5
./create_guac_admin.sh "${NEW_ADMIN_USER}" "${NEW_ADMIN_PASS}"

echo "Install Nginx"
apt-get install -y -qq nginx

cp ./guacamole /etc/nginx/sites-available/guacamole
ln -s /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

if [[ -f fullchain.pem && -f privkey.pem ]]; then
    echo "Use existing certificate"
    mkdir -p /etc/letsencrypt/live/nerdapp.work/
    cp fullchain.pem privkey.pem /etc/letsencrypt/live/nerdapp.work/
    chown -R root:root /etc/letsencrypt/live/nerdapp.work/
    chmod 755 /etc/letsencrypt/live/nerdapp.work/
    chmod 644 /etc/letsencrypt/live/nerdapp.work/fullchain.pem
    chmod 600 /etc/letsencrypt/live/nerdapp.work/privkey.pem
else
    echo "dns_cloudflare_api_token = ${CLOUDFLARE_API_TOKEN}" > ~/cloudflare.ini
    chmod 600 ~/cloudflare.ini

    echo "Install Certbot"
    apt-get install -y -qq certbot python3-certbot-dns-cloudflare
    echo "Create wildcard certificate"
    # LETS_ENCRYPT_URL=https://acme-staging-v02.api.letsencrypt.org/directory
    LETS_ENCRYPT_URL=https://acme-v02.api.letsencrypt.org/directory
    certbot certonly \
      --dns-cloudflare \
      --dns-cloudflare-credentials ~/cloudflare.ini \
      --dns-cloudflare-propagation-seconds 60 \
      --server "${LETS_ENCRYPT_URL}" \
      --non-interactive \
      --agree-tos \
      --email "${CLOUDFLARE_EMAIL}" \
      -d "*.nerdapp.work"
fi

echo "Restart Nginx"
systemctl reload nginx
