#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="fever"
JOB="fever-client"

echo "==> Running client test"

kubectl delete job "${JOB}" \
    --namespace "${NAMESPACE}" \
    --ignore-not-found

kubectl apply -f kubernetes/client-job.yaml

echo "==> Waiting for client test"

kubectl wait \
    --for=condition=complete \
    job/"${JOB}" \
    --namespace "${NAMESPACE}" \
    --timeout=120s

echo
echo "==> Client output"

kubectl logs \
    --namespace "${NAMESPACE}" \
    job/"${JOB}"

echo
echo "Client test completed successfully."
