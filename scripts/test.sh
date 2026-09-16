#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="fever"
CLIENT_DEPLOYMENT="fever-client"

echo "==> Checking client deployment"

kubectl rollout status deployment/"${CLIENT_DEPLOYMENT}" \
    --namespace "${NAMESPACE}" \
    --timeout=120s

echo "==> Waiting for internal DNS"

for attempt in {1..30}; do
    if kubectl exec \
        --namespace "${NAMESPACE}" \
        deployment/"${CLIENT_DEPLOYMENT}" \
        -- getent hosts server.example.com >/dev/null 2>&1; then

        echo "Internal DNS is ready."
        break
    fi

    if [[ "${attempt}" -eq 30 ]]; then
        echo "ERROR: Internal DNS did not become ready."
        exit 1
    fi

    sleep 2
done

echo "==> Waiting for client requests"

sleep 16

echo
echo "==> Client output"

CLIENT_LOGS=$(kubectl logs \
    --namespace "${NAMESPACE}" \
    deployment/"${CLIENT_DEPLOYMENT}" \
    --tail=20)

echo "${CLIENT_LOGS}"

echo
echo "==> Validating client responses"

for host in server server.example.com server.local; do
    if ! grep -q "Response from https://${host}:443:" <<< "${CLIENT_LOGS}"; then
        echo "ERROR: No successful response found for ${host}."
        exit 1
    fi

    echo "${host}: OK"
done

echo
echo "Client test completed successfully."
