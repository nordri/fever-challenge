#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="fever"

echo "==> Removing Fever namespace"

kubectl delete namespace "${NAMESPACE}" \
    --ignore-not-found \
    --wait=true

echo "==> Removing NGINX Ingress Controller"

kubectl delete -f kubernetes/ingress-nginx/controller.yaml \
    --ignore-not-found \
    --wait=true

echo "==> Restoring CoreDNS"

# Remove our custom DNS rewrites.
# This assumes coredns-configmap.yaml is our modified Killerkoda CoreDNS
# configuration and restores the original Corefile separately.
kubectl apply -f kubernetes/coredns-configmap-original.yaml

echo
echo "==> Verifying cleanup"

kubectl get namespace "${NAMESPACE}" 2>/dev/null || true
kubectl get namespace ingress-nginx 2>/dev/null || true

echo
echo "Cleanup completed successfully."
