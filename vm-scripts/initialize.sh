#!/usr/bin/env bash

# Allow login w/ passwd
sed --in-place 's/^#?PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl reload ssh

# Install K3
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --cluster-init --write-kubeconfig-mode=644 --disable=traefik" sh
sleep 20

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Install Traefik
cat > traefik-values.yaml <<EOF
## File values.yaml ##
providers:
  # Disable the Ingress provider (optional)
  # We do not want to use Ingress objects anymore!
  kubernetesIngress:
    enabled: true
  # Enable the GatewayAPI provider
  kubernetesGateway:
    enabled: true
# Allow the Gateway to expose HTTPRoute from all namespaces
gateway:
  listeners:
    web:
      namespacePolicy:
        from: All
EOF

helm repo add traefik https://traefik.github.io/charts
helm repo update
mkdir -p "${HOME}/.kube"
cp /etc/rancher/k3s/k3s.yaml "/${HOME}/.kube/config"
chown -R "${USER}:${USER}" "/${HOME}/.kube"
kubectl create namespace traefik
helm upgrade --install --namespace traefik traefik traefik/traefik -f traefik-values.yaml

# Install K9s
wget -q -O - https://github.com/derailed/k9s/releases/download/v0.50.16/k9s_Linux_amd64.tar.gz | tar xz -C /usr/local/bin k9s
chown root:root /usr/local/bin/k9s
