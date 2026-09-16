# Fever — Kubernetes

This repository contains my solution for the Kubernetes part of the Fever Systems hiring challenge.

The goal is to deploy the provided server and client applications in Kubernetes and expose the server through an NGINX Ingress Controller using HTTPS and the required hostnames.

The solution was implemented and validated using a Killerkoda Kubernetes environment.

## Architecture

The deployed request path is:

```text
fever-client
    |
    | HTTPS
    v
CoreDNS
    |
    v
NGINX Ingress Controller
    |
    | HTTPS :5000
    v
fever-server Service
    |
    v
fever-server Pod
```

The following hostnames are supported:

- `server`
- `server.example.com`
- `server.local`

All three names resolve internally to the NGINX Ingress Controller.

The Ingress Controller terminates the client TLS connection and proxies the request to the Fever server using HTTPS.

## Repository structure

```text
.
├── client/
├── kubernetes/
│   ├── ingress-nginx/
│   ├── client-deployment.yaml
│   ├── coredns-configmap-original.yaml
│   ├── coredns-configmap.yaml
│   ├── server-deployment.yaml
│   ├── server-ingress.yaml
│   └── server-service.yaml
├── scripts/
│   ├── cleanup.sh
│   ├── collect-evidence.sh
│   ├── deploy.sh
│   ├── setup-killerkoda.sh
│   └── test.sh
└── server/
```

## Requirements

The solution was tested on Killerkoda with:

- Kubernetes
- containerd
- Docker
- `kubectl`
- `ctr`
- Bash
- OpenSSL

The Killerkoda cluster uses containerd as the Kubernetes container runtime.

No external container registry is required.

## Setup

The setup script prepares the application artifacts required by the cluster:

```bash
./scripts/setup-killerkoda.sh
```

It performs the following operations:

1. Generates the server TLS certificates.
2. Validates the certificates.
3. Builds the server and client Docker images.
4. Exports the images as local archives.
5. Imports the images into the Kubernetes containerd image store.
6. Distributes the images to available worker nodes.

Images are deliberately loaded directly into the nodes instead of being published to a public registry.

The Kubernetes manifests use:

```yaml
imagePullPolicy: Never
```

so Kubernetes always uses the locally imported images.

## Deployment

Deploy the solution with:

```bash
./scripts/deploy.sh
```

The deployment script:

1. Creates the `fever` namespace.
2. Creates the TLS Secret used by the workloads.
3. Deploys the Fever server and its Service.
4. Deploys the NGINX Ingress Controller.
5. Waits for the controller to become available.
6. Deploys the application Ingress.
7. Configures CoreDNS with the required internal DNS entries.
8. Deploys the client.

The scripts are designed to be safe to execute repeatedly where possible, using declarative Kubernetes operations rather than assuming an empty cluster.

## Testing

Run the smoke test with:

```bash
./scripts/test.sh
```

The client continuously performs HTTPS requests against the three required addresses:

```text
https://server:443
https://server.example.com:443
https://server.local:443
```

A request is made every five seconds.

A successful test produces output similar to:

```text
Response from https://server:443: Domain: server, Client IP: <ingress-ip>
Response from https://server.example.com:443: Domain: server.example.com, Client IP: <ingress-ip>
Response from https://server.local:443: Domain: server.local, Client IP: <ingress-ip>

server: OK
server.example.com: OK
server.local: OK

Client test completed successfully.
```

The NGINX access logs can also be inspected with:

```bash
kubectl logs \
  -n ingress-nginx \
  deployment/ingress-nginx-controller
```

They show the client requests reaching NGINX and being forwarded to the Fever server backend.

## DNS design

The application requires the names:

```text
server
server.example.com
server.local
```

to reach the NGINX Ingress Controller.

CoreDNS is therefore configured so these names resolve internally to the `ingress-nginx-controller` Service.

This keeps the complete request path inside the Kubernetes cluster:

```text
client Pod
    -> cluster DNS
    -> ingress-nginx Service
    -> ingress-nginx Pod
    -> fever-server Service
    -> fever-server Pod
```

No external DNS infrastructure is required.

## TLS

The supplied applications use HTTPS and certificate validation is kept enabled.

The generated server certificate is stored as the Kubernetes TLS Secret:

```text
fever/server-tls
```

The certificate is used by the application Ingress for TLS termination and is also made available to the client as the trusted certificate required to validate the HTTPS connection.

NGINX is configured to communicate with the Fever server backend using HTTPS.

Certificate validation is not disabled in the client.

## Scheduling and multi-node validation

The solution does not rely on the client and server running on the same Kubernetes node.

During validation, the client was explicitly scheduled on the control-plane node while the server and NGINX Ingress Controller were running on the worker node.

The resulting traffic successfully crossed nodes:

```text
client (controlplane)
    -> NGINX Ingress (worker)
    -> fever-server (worker)
```

This verified that DNS resolution, Service routing, Ingress routing and the CNI networking path work independently of Pod co-location.

Node-specific scheduling used during this validation was only for testing and is not required by the normal client deployment.

## Automation

The helper scripts are intentionally separated by responsibility:

```text
setup-killerkoda.sh   Build and distribute local images
deploy.sh             Deploy and configure Kubernetes resources
test.sh               Validate application behaviour
collect-evidence.sh   Capture final cluster state and logs
cleanup.sh            Remove challenge resources
```

Deployment and testing are separate operations intentionally. Deploying establishes the desired cluster state; testing validates that state afterwards.

## Evidence

Evidence can be collected with:

```bash
./scripts/collect-evidence.sh
```

The script captures the final Kubernetes state, relevant manifests, DNS configuration, certificate metadata, image distribution and application/Ingress logs.

It also creates a compressed archive for convenient extraction outside the ephemeral Killerkoda environment.

## Cleanup

Remove the deployed challenge resources with:

```bash
./scripts/cleanup.sh
```

## Design decisions and trade-offs

### Local images instead of a registry

The challenge must not use a public container registry.

Images are therefore built locally and imported directly into each Kubernetes node's containerd image store.

This adds a small amount of setup logic but keeps the environment fully self-contained.

In a production environment I would normally use a private container registry and immutable image references.

### CoreDNS for internal names

The required hostnames are resolved inside the cluster through CoreDNS.

This allows all client traffic to remain internal and avoids depending on external DNS or modifying individual Pods.

In a production environment, DNS design would depend on the actual ownership and lifecycle of the domains and the cluster infrastructure.

### NGINX Ingress

NGINX provides a single entry point for all required hostnames and keeps routing configuration in Kubernetes resources.

The Fever server remains behind a ClusterIP Service and does not need to be directly exposed.

### TLS

TLS verification remains enabled throughout the client-facing connection.

The challenge uses locally generated certificates because the environment is isolated and ephemeral. Production certificates and private keys would normally be managed through an appropriate certificate-management and secret-management solution rather than generated as part of a local setup workflow.

### Killerkoda environment

Killerkoda is an ephemeral training environment and has some characteristics that influence the implementation, particularly local image distribution and node scheduling.

The solution avoids relying on those characteristics for the application architecture itself.

## Bonus 1 — Continuous client

The original client execution model was adapted to continuously send requests every five seconds.

Because the process is now long-running rather than finite, it is deployed as a Kubernetes `Deployment` instead of a `Job`.

The client preserves TLS certificate validation and continuously cycles through the three required hostnames.

## Bonus 2 — AWS ALB example

An additional example shows how an AWS Application Load Balancer could be placed in front of the NGINX Ingress Controller using AWS Load Balancer Controller annotations.

The intended architecture is:

```text
Internet
    |
    | HTTPS
    v
AWS ALB
    |
    v
NGINX Ingress Controller
    |
    v
Fever Ingress
    |
    v
fever-server
```

The example is illustrative and is not deployed by the Killerkoda scripts because the test environment does not provide AWS infrastructure.

In a real AWS environment, values such as the ACM certificate ARN, networking configuration, security groups, DNS and health checks would be adapted to the target cluster.

## Final validation

The solution was tested from a clean Killerkoda environment using the provided automation.

Successful validation confirmed:

- local image building and distribution;
- Kubernetes deployment;
- internal DNS resolution;
- HTTPS connectivity;
- TLS certificate validation;
- routing through NGINX Ingress;
- connectivity to the Fever server;
- continuous five-second client requests;
- and cross-node Kubernetes networking.