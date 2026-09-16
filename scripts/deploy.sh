#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="fever"
TLS_SECRET="server-tls"

echo "==> Creating namespace"
kubectl create namespace "${NAMESPACE}" \
    --dry-run=client \
    -o yaml | kubectl apply -f -

echo "==> Creating TLS secret"
kubectl create secret tls "${TLS_SECRET}" \
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
    --namespace "${NAMESPACE}" \
    --timeout=120s

echo "==> Deploying NGINX Ingress Controller"
kubectl apply -f kubernetes/ingress-nginx/controller.yaml

echo "==> Waiting for NGINX Ingress Controller"
kubectl rollout status deployment/ingress-nginx-controller \
    --namespace ingress-nginx \
    --timeout=120s

echo "==> Deploying application Ingress"
for attempt in {1..6}; do
    if kubectl apply -f kubernetes/server-ingress.yaml; then
        break
    fi

    if [[ "${attempt}" -eq 6 ]]; then
        echo "ERROR: Failed to deploy application Ingress after ${attempt} attempts."
        exit 1
    fi

    echo "Ingress admission webhook not ready, retrying in 5 seconds..."
    sleep 5
done

echo "==> Configuring CoreDNS"
kubectl apply -f kubernetes/coredns-configmap.yaml

echo "==> Waiting for CoreDNS reload"
kubectl rollout status deployment/coredns \
    --namespace kube-system \
    --timeout=120s

echo "==> Deploying client service"
kubectl apply -f kubernetes/client-deployment.yaml

echo "==> Waiting for client"
kubectl rollout status deployment/fever-client \
    --namespace "${NAMESPACE}" \
    --timeout=120s

echo
echo "==> Deployment status"
kubectl get pods -n "${NAMESPACE}" -o wide
kubectl get pods -n ingress-nginx -o wide

echo
echo "Deployment completed successfully."
