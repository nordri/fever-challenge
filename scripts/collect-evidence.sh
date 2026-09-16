#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="fever"
EVIDENCE_DIR="evidence"
DUMP_DIR="${EVIDENCE_DIR}/dump-cluster"
LOG_DIR="${EVIDENCE_DIR}/logs"
ARCHIVE="fever-evidence.tar.gz"

echo "==> Preparing evidence directories"

rm -rf "${EVIDENCE_DIR}"
mkdir -p "${DUMP_DIR}" "${LOG_DIR}"

echo "==> Collecting cluster information"

kubectl get nodes -o wide \
    > "${DUMP_DIR}/nodes.txt"

kubectl get pods -A -o wide \
    > "${DUMP_DIR}/pods-all-wide.txt"

kubectl get pods -n "${NAMESPACE}" -o wide \
    > "${DUMP_DIR}/fever-pods-wide.txt"

echo "==> Collecting Fever resources"

kubectl get all -n "${NAMESPACE}" -o yaml \
    > "${DUMP_DIR}/fever-all.yaml"

kubectl get deployment fever-server \
    -n "${NAMESPACE}" \
    -o yaml \
    > "${DUMP_DIR}/server-deployment.yaml"

kubectl get service fever-server \
    -n "${NAMESPACE}" \
    -o yaml \
    > "${DUMP_DIR}/server-service.yaml"

kubectl get ingress fever-server \
    -n "${NAMESPACE}" \
    -o yaml \
    > "${DUMP_DIR}/server-ingress.yaml"

kubectl get deployment fever-client \
    -n "${NAMESPACE}" \
    -o yaml \
    > "${DUMP_DIR}/client-deployment.yaml"

kubectl logs \
    -n "${NAMESPACE}" \
    deployment/fever-client \
    > "${LOG_DIR}/client.log"

echo "==> Collecting DNS configuration"

kubectl get configmap coredns \
    -n kube-system \
    -o yaml \
    > "${DUMP_DIR}/coredns-configmap.yaml"

echo "==> Collecting NGINX Ingress resources"

kubectl get deployment ingress-nginx-controller \
    -n ingress-nginx \
    -o yaml \
    > "${DUMP_DIR}/ingress-nginx-controller.yaml"

kubectl get service ingress-nginx-controller \
    -n ingress-nginx \
    -o yaml \
    > "${DUMP_DIR}/ingress-nginx-service.yaml"

kubectl get ingressclass nginx \
    -o yaml \
    > "${DUMP_DIR}/ingressclass.yaml"

echo "==> Collecting certificate metadata"

openssl x509 \
    -in server/certs/server.crt \
    -noout \
    -subject \
    -issuer \
    -dates \
    -fingerprint \
    -sha256 \
    -ext subjectAltName \
    > "${DUMP_DIR}/server-certificate.txt"

echo "==> Collecting client logs"

kubectl logs \
    -n "${NAMESPACE}" \
    job/fever-client \
    > "${LOG_DIR}/client.log"

echo "==> Collecting server logs"

kubectl logs \
    -n "${NAMESPACE}" \
    deployment/fever-server \
    > "${LOG_DIR}/server.log"

echo "==> Collecting NGINX Ingress logs"

kubectl logs \
    -n ingress-nginx \
    deployment/ingress-nginx-controller \
    > "${LOG_DIR}/ingress-nginx.log"

echo "==> Collecting image distribution"

{
    echo "=== controlplane ==="
    ctr -n k8s.io images list | grep -E 'fever-(server|client)'

    mapfile -t WORKER_NODES < <(
        kubectl get nodes \
            --selector='!node-role.kubernetes.io/control-plane' \
            -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
    )

    for node in "${WORKER_NODES[@]}"; do
        echo
        echo "=== ${node} ==="
        ssh "${node}" \
            "ctr -n k8s.io images list | grep -E 'fever-(server|client)'"
    done
} > "${DUMP_DIR}/images-multinode.txt" 2>&1

echo "==> Creating evidence archive"

rm -f "${ARCHIVE}"

tar czf "${ARCHIVE}" "${EVIDENCE_DIR}"

echo
echo "Evidence collected successfully."
echo
echo "Directory:"
du -sh "${EVIDENCE_DIR}"

echo
echo "Archive:"
ls -lh "${ARCHIVE}"

echo
echo "Contents:"
tar tzf "${ARCHIVE}"
