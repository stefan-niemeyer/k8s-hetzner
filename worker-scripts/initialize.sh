#!/usr/bin/env bash

# Allow login w/ passwd
sed --in-place 's/^#?PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl reload ssh

echo "Install K3"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --cluster-init --write-kubeconfig-mode=644 --disable=traefik" sh
sleep 20

echo "Install Helm"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

echo "Gateway CRDs installieren Traefik"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.5/docs/content/reference/dynamic-configuration/kubernetes-gateway-rbac.yml

echo "Install Traefik"
cat > traefik-values.yaml <<EOF
## File values.yaml ##
providers:
  # Disable the Ingress provider (optional)
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

echo "Install Wildcard Certificate and API Gateway"
kubectl create namespace nerdapp-work --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f nerdapp-work-tls.yaml
kubectl apply -f nerdapp-work-gateway.yaml

echo "Install Longhorn"
apt-get update -qq
apt-get install -y -qq nfs-common open-iscsi
systemctl enable --now iscsid

helm repo add longhorn https://charts.longhorn.io
helm repo update
helm upgrade --install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.11.1

echo "Install K9s"
wget -q -O - https://github.com/derailed/k9s/releases/download/v0.50.18/k9s_Linux_amd64.tar.gz | tar xz -C /usr/local/bin k9s
chown root:root /usr/local/bin/k9s
