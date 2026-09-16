# Bonus 2 — AWS ALB + NGINX Ingress

This directory contains an illustrative example of how the NGINX Ingress Controller used in the challenge could be exposed through an AWS Application Load Balancer.

The example is not deployed by the Killerkoda automation and requires the AWS Load Balancer Controller and an AWS environment.

## Architecture

```text
Internet
    |
    | HTTPS :443
    v
AWS Application Load Balancer
    |
    v
ingress-nginx-controller Service
    |
    v
NGINX Ingress
    |
    v
fever-server Service
    |
    v
fever-server Pod
```

Two different Ingress controllers have separate responsibilities:

- **AWS Load Balancer Controller** manages the external ALB.
- **NGINX Ingress Controller** keeps the application routing used by the challenge.

The ALB-facing Ingress therefore uses:

```yaml
ingressClassName: alb
```

while the application Ingress continues using:

```yaml
ingressClassName: nginx
```

## Main ALB annotations

The example includes the principal AWS Load Balancer Controller annotations:

```yaml
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/target-type: ip
alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:eu-west-1:123456789012:certificate/example
```

These configure an internet-facing ALB, use Kubernetes Pod IP networking for targets, expose an HTTPS listener and associate an ACM certificate.

TLS is terminated at the ALB in this example, and traffic is then forwarded to the NGINX Ingress Controller.

## Production considerations

This manifest is intentionally an example rather than a production-ready AWS deployment.

In a real environment, the ACM certificate ARN, DNS, VPC/subnets, security groups, health checks and TLS strategy would be configured according to the target EKS infrastructure and security requirements.

The example is kept separate from the Killerkoda manifests so the AWS-specific bonus does not affect the reproducible local solution.