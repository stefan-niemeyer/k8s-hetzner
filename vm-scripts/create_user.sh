#!/usr/bin/env bash

if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
  echo "Usage $(basename $0) host-alias user passwd"
  exit 1
fi

set -e     # exit script if a command fails

HOST_ALIAS="$1"
VM_USER="$2"
VM_PASSWD="$3"

# Create user
useradd --create-home --shell /bin/bash "${VM_USER}"
echo "${VM_USER}:${VM_PASSWD}" | chpasswd

# Prepare k3s access for user
kubectl create namespace "${VM_USER}"
kubectl config set-context --current --namespace="${VM_USER}"
mkdir -p "/home/${VM_USER}/.kube"
cp /etc/rancher/k3s/k3s.yaml "/home/${VM_USER}/.kube/config"
chown -R "${VM_USER}:${VM_USER}" "/home/${VM_USER}/.kube"

# Configure .profile
(
  echo 'export KUBECONFIG=$HOME/.kube/config'
  echo "export EXTERNAL_DNS=${HOST_ALIAS}.laserschwert.io"
  echo 'alias k=kubectl'
  echo "alias ktools='kubectl run tools --rm -it --image wbitt/network-multitool -- /bin/bash'"
  echo "alias setpod='export POD_NAME=\$(kubectl get pods -l app=k8s-demo-vx -o jsonpath=\"{.items[*].metadata.name}\")'"
) >> "/home/${VM_USER}/.profile"
