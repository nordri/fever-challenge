#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="fever"
CLIENT_DEPLOYMENT="fever-client"

echo "==> Checking client deployment"
kubectl rollout status deployment/"${CLIENT_DEPLOYMENT}" \
    --namespace "${NAMESPACE}" \
    --timeout=120s

echo "==> Waiting for client requests"
sleep 16

echo
echo "==> Client output"
kubectl logs \
    --namespace "${NAMESPACE}" \
    deployment/"${CLIENT_DEPLOYMENT}" \
    --tail=20

echo
echo "Client test completed."
