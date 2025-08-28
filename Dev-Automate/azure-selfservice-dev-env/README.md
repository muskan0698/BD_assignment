
# Azure Self-Service Dev Environment

This project provisions a self-service dev environment on Azure with cost controls.

## Components
- Resource Group
- VNet + Subnet
- NSG with SSH rule
- Ubuntu Linux VM (private)
- Log Analytics for monitoring
- Auto-shutdown schedule (8 PM UTC daily)
- Monthly budget alert ($50, emails at 80%)

## Usage

### Local
```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

### Azure DevOps
- Create a new pipeline using `azure-pipelines.yml`
- Add service connection to Azure
- Run pipeline (Plan -> Apply)
```
