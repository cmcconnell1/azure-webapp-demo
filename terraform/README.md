Terraform layout (scaffold)

- Root holds provider and shared config (providers.tf, versions.tf, backend.tf)
- Environments contain per-env backend.conf and terraform.tfvars[.example]

Bootstrapping remote state (automated)
```bash
# Creates state RG + Storage Account + container; writes environments/<env>/backend.conf
./scripts/bootstrap-tf-backend.sh --env dev --project-prefix webapp-demo --location westus2
```

Manual (advanced)
```bash
# Or prepare backend.conf with an existing state RG/SA
./scripts/prepare-backend.sh --env dev --state-rg <state-rg> --state-sa <state-sa>
```

Plan/Apply from root module
```bash
# Copy tfvars example if needed
cp -n environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars || true

terraform -chdir=. init -backend-config=environments/dev/backend.conf
terraform -chdir=. plan -var-file=environments/dev/terraform.tfvars
terraform -chdir=. apply -auto-approve -var-file=environments/dev/terraform.tfvars
```

One-command wrapper
```bash
# Provision end-to-end
../scripts/dev-up.sh --env dev --project-prefix webapp-demo --location westus2
```
