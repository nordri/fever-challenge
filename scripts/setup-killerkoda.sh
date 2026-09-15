#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="fever"
SERVER_IMAGE="fever-server:0.1.0"
CLIENT_IMAGE="fever-client:0.1.0"

SERVER_IMAGE_TAR="/tmp/fever-server.tar"
CLIENT_IMAGE_TAR="/tmp/fever-client.tar"

SECRET="server-tls"

echo "==> Generating server certificates"
make -C server create-certs

echo "==> Validating server certificates"
make -C server validate-certs

echo "==> Building server image"
make -C server build

echo "==> Building client image"
make -C client build

echo "==> Exporting Docker image"
docker save "${SERVER_IMAGE}" -o "${SERVER_IMAGE_TAR}"
docker save "${CLIENT_IMAGE}" -o "${CLIENT_IMAGE_TAR}"

echo "==> Importing image into Kubernetes containerd"
ctr -n k8s.io images import "${SERVER_IMAGE_TAR}"
ctr -n k8s.io images import "${CLIENT_IMAGE_TAR}"

echo "==> Verifying Kubernetes images"
ctr -n k8s.io images list | grep -E 'fever-(server|client)'

echo "==> Deploying Ingress Controller"
kubectl apply -f kubernetes/ingress-nginx/controller.yaml
kubectl rollout status deployment/ingress-nginx-controller \
  -n ingress-nginx \
  --timeout=120s

echo "==> Updating CoreDNS Configmap"
kubectl apply -f kubernetes/coredns-configmap.yaml

echo "==> Creating namespace"
kubectl create namespace "${NAMESPACE}" \
    --dry-run=client \
    -o yaml | kubectl apply -f -

echo "==> Creating TLS secret"
kubectl create secret tls "${SECRET}" \
    --namespace "${NAMESPACE}" \
    --cert=server/certs/server.crt \
    --key=server/certs/server.key \
    --dry-run=client \
    -o yaml | kubectl apply -f -

echo "==> Deploying server"
kubectl apply -f kubernetes/server-deployment.yaml
kubectl apply -f kubernetes/server-service.yaml

echo "==> Waiting for server"
kubectl rollout status deployment/fever-server \
    --namespace "${NAMESPACE}"

echo
echo "Killerkoda environment ready."
kubectl get pods -n "${NAMESPACE}" -o wide
