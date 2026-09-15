#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="fever"
IMAGE="fever-server:0.1.0"
IMAGE_TAR="/tmp/fever-server.tar"
SECRET="server-tls"

echo "==> Generating server certificates"
make -C server create-certs

echo "==> Validating server certificates"
make -C server validate-certs

echo "==> Building server image"
make -C server build

echo "==> Exporting Docker image"
docker save "${IMAGE}" -o "${IMAGE_TAR}"

echo "==> Importing image into Kubernetes containerd"
ctr -n k8s.io images import "${IMAGE_TAR}"

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

echo "==> Waiting for server"
kubectl rollout status deployment/fever-server \
    --namespace "${NAMESPACE}"

echo
echo "Killerkoda environment ready."
kubectl get pods -n "${NAMESPACE}" -o wide

