# Kubernetes Challenge — Evidence

This directory contains the runtime evidence collected during the validation of the main Kubernetes challenge in a Killerkoda environment.

The evidence represents the working core implementation, before the optional continuous-client bonus was implemented. In this snapshot, the client therefore runs as a Kubernetes `Job`.

The Bonus 1 implementation later replaces this Job with a long-running `Deployment`; its configuration is available in the repository but is not part of this evidence snapshot.

## Structure

```text
evidence/
├── README.md
├── dump-cluster/
│   ├── client-job.yaml
│   ├── coredns-configmap.yaml
│   ├── fever-all.yaml
│   ├── fever-pods-wide.txt
│   ├── images-multinode.txt
│   ├── ingress-nginx-controller.yaml
│   ├── ingress-nginx-service.yaml
│   ├── ingressclass.yaml
│   ├── nodes.txt
│   ├── pods-all-wide.txt
│   ├── server-certificate.txt
│   ├── server-deployment.yaml
│   ├── server-ingress.yaml
│   └── server-service.yaml
└── logs/
    ├── client.log
    ├── ingress-nginx.log
    └── server.log
```

## Cluster state

### `dump-cluster/nodes.txt`

Shows the Kubernetes nodes and their runtime information.

### `dump-cluster/pods-all-wide.txt`

Shows Pods across the cluster, including their Pod IPs and assigned nodes.

### `dump-cluster/fever-pods-wide.txt`

Contains the Pod state specifically for the `fever` namespace, including Pod IP addresses and node placement.

### `dump-cluster/fever-all.yaml`

Contains the effective Kubernetes resource state for the `fever` namespace at evidence collection time.

## Application resources

### `dump-cluster/server-deployment.yaml`

Effective Kubernetes Deployment for the Fever server.

### `dump-cluster/server-service.yaml`

Effective Kubernetes Service exposing the Fever server internally.

### `dump-cluster/server-ingress.yaml`

Effective Ingress configuration containing the routing rules for:

```text
server
server.example.com
server.local
```

### `dump-cluster/client-job.yaml`

Effective Kubernetes Job used to execute the client during validation of the main challenge.

The Job performs HTTPS requests against the three required server addresses and completes after executing the client.

The optional Bonus 1 subsequently changes the client execution model to a continuous Kubernetes Deployment.

## DNS

### `dump-cluster/coredns-configmap.yaml`

Contains the effective CoreDNS configuration used during validation.

The custom DNS configuration makes the required hostnames resolve internally to the NGINX Ingress entry point.

## NGINX Ingress

### `dump-cluster/ingress-nginx-controller.yaml`

Effective NGINX Ingress Controller Deployment.

### `dump-cluster/ingress-nginx-service.yaml`

Effective Service for the NGINX Ingress Controller.

### `dump-cluster/ingressclass.yaml`

IngressClass configuration used by the Fever application Ingress.

## TLS

### `dump-cluster/server-certificate.txt`

Contains metadata for the TLS certificate used by the solution.

The private key is deliberately not included in the evidence.

TLS certificate validation remained enabled in the client.

## Container images

### `dump-cluster/images-multinode.txt`

Shows the Fever container images available in the Kubernetes containerd image stores.

The images were built locally and imported directly into the nodes instead of being published to a public container registry.

## Runtime logs

### `logs/client.log`

Contains the output from the client Job.

Successful entries demonstrate HTTPS connectivity to:

```text
https://server:443
https://server.example.com:443
https://server.local:443
```

### `logs/ingress-nginx.log`

Contains NGINX Ingress Controller logs.

The access log entries demonstrate that requests reached the Ingress Controller and were successfully proxied to the Fever server backend.

### `logs/server.log`

Contains application logs captured from the Fever server Deployment.

## Evidence collection

The evidence was generated using:

```bash
./scripts/collect-evidence.sh
```

The script captures the effective cluster configuration, image state, certificate metadata and relevant runtime logs.

The collection process is read-only with respect to the deployed application.

## What this evidence demonstrates

This snapshot demonstrates the successful end-to-end execution of the main Kubernetes challenge:

```text
client Job
    |
    | HTTPS
    v
CoreDNS
    |
    v
NGINX Ingress Controller
    |
    | HTTPS
    v
fever-server Service
    |
    v
fever-server Pod
```

Specifically, the captured state and logs show that:

- the Fever server and client ran successfully in Kubernetes;
- the required hostnames resolved inside the cluster;
- HTTPS requests were performed with certificate validation enabled;
- all three required hostnames were routed through NGINX Ingress;
- NGINX successfully forwarded requests to the Fever server backend;
- the solution was validated in a multi-node Kubernetes environment;
- and the container images were distributed locally without using a public registry.

The evidence is intentionally retained as the snapshot produced during validation of the main challenge. Optional changes implemented afterwards, including the continuous-client Bonus 1, are represented by the final source code and manifests rather than by regenerating this runtime snapshot.