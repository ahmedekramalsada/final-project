# NTI Final Project — AWS EKS + API Gateway + GitOps

Mock enterprise stack on AWS: VPC + EKS + NLB fronted by a single API Gateway with Cognito JWT auth, tools via Helm (ArgoCD, SonarQube, Nexus, Datadog, KEDA). Secrets come from HashiCorp Vault — no secrets in git.

Traffic: `User → API Gateway (Cognito) → VPC Link → NLB → Ingress Nginx → Service`

## Quickstart

```bash
# app
cd final-project-nti/app && npm install && node server.js

# infra (needs AWS creds + Vault)
cd final-project-nti/terraform/infrastructure && terraform init && terraform plan
cd ../tools && terraform init && terraform plan

# k8s manifests
kubectl apply -k final-project-nti/k8s/  # or via ArgoCD app-of-apps
```

See `final-project-nti/README.md` + `PROJECT_BREAKDOWN.md` for full architecture, destroy order (tools → infra), and pipeline docs.

## Layout

```
final-project-nti/
  app/            # Node demo service + Dockerfile
  terraform/
    infrastructure/  # VPC, EKS, NLB, API GW, Cognito, Vault secrets
    tools/           # Helm: ArgoCD, SonarQube, Nexus, Datadog, KEDA
  k8s/            # Deployment, Service, Ingress, ArgoCD app, KEDA
  pipelines/      # infra / tools / app / destroy pipelines
  scripts/        # cleanup helpers
```

## Pipelines

- `infrastructure-pipeline.yml` — Terraform apply/destroy infra
- `tools-pipeline.yml` — Terraform apply/destroy tools
- `application-pipeline.yml` — build, scan, push, ArgoCD deploy
- `destroy-pipeline.yml` — ordered destroy: tools → infrastructure

## Security

- Cognito JWT at API Gateway, Vault for secrets (`secrets.tf` reads `kv/app`, no values in repo)
- `*.tfvars` / `*.tfstate` gitignored. Do not commit real `terraform.tfvars`.

## License

MIT — see [LICENSE](LICENSE).
