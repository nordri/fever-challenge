#!/usr/bin/env bash

set -euo pipefail

SERVER_IMAGE="fever-server:0.1.0"
CLIENT_IMAGE="fever-client:0.1.0"

SERVER_IMAGE_TAR="/tmp/fever-server.tar"
CLIENT_IMAGE_TAR="/tmp/fever-client.tar"

echo "==> Checking cluster nodes"
kubectl get nodes -o wide

echo "==> Generating server certificates"
make -C server create-certs

echo "==> Validating server certificates"
make -C server validate-certs

echo "==> Building server image"
make -C server build

echo "==> Building client image"
make -C client build

echo "==> Exporting Docker images"
docker save "${SERVER_IMAGE}" -o "${SERVER_IMAGE_TAR}"
docker save "${CLIENT_IMAGE}" -o "${CLIENT_IMAGE_TAR}"

echo "==> Importing images into local Kubernetes containerd"
ctr -n k8s.io images import "${SERVER_IMAGE_TAR}"
ctr -n k8s.io images import "${CLIENT_IMAGE_TAR}"

echo "==> Importing images into worker nodes"
mapfile -t WORKER_NODES < <(
    kubectl get nodes \
        --selector='!node-role.kubernetes.io/control-plane' \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
)

if [[ ${#WORKER_NODES[@]} -eq 0 ]]; then
    echo "ERROR: No worker nodes found."
    exit 1
fi

for node in "${WORKER_NODES[@]}"; do
    echo "==> Loading images into ${node}"

    ssh "${node}" "ctr -n k8s.io images import -" < "${SERVER_IMAGE_TAR}"
    ssh "${node}" "ctr -n k8s.io images import -" < "${CLIENT_IMAGE_TAR}"
done

echo "==> Verifying images on control plane"
ctr -n k8s.io images list | grep -E 'fever-(server|client)'

for node in "${WORKER_NODES[@]}"; do
    echo "==> Verifying images on ${node}"

    ssh "${node}" \
        "ctr -n k8s.io images list | grep -E 'fever-(server|client)'"
done

echo
echo "Killerkoda bootstrap completed successfully."
