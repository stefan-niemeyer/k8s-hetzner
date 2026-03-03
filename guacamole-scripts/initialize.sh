#!/usr/bin/env bash

echo "🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶 ${0##*/} 🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶"

NEW_ADMIN_USER="$1"
NEW_ADMIN_PASS="$2"

# Allow login w/ passwd
#sed --in-place 's/^#?PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
#systemctl reload ssh

echo "Remove old docker versions and update system"
apt update && apt upgrade -y
apt-get remove docker docker-engine docker.io containerd runc

echo "Install dependencies and GPG key"
apt install ca-certificates curl gnupg lsb-release uuid jq -y
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "Add Docker as apt source"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Install Docker Engine and Compose"
apt update
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

#echo "Create user '${VM_USER}'"
#useradd --create-home --shell /bin/bash "${VM_USER}"
#echo "${VM_USER}:${VM_PASSWD}" | chpasswd

#usermod -aG docker "${VM_USER}"
# newgrp docker

# start Guacamole
./guac-setup.sh
sleep 5
./create_guac_admin.sh "${NEW_ADMIN_USER}" "${NEW_ADMIN_PASS}"

echo "Install Nginx"
apt install nginx -y

echo "Install Certbot"
apt install certbot python3-certbot-nginx -y

cp ./guacamole /etc/nginx/sites-available/guacamole
ln -s /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

echo "Configure and restart Nginx"
systemctl reload nginx
certbot --nginx \
  --non-interactive \
  --agree-tos \
  -m stefan@niemeyer.de \
  -d ssh.nerdapp.work
