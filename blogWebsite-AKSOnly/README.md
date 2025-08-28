1. Project Overview

The goal of this project is to deploy a blog application consisting of:

A frontend (web interface)

A backend API (for blog logic and database connection)

A SQL database (managed Azure SQL DB)

Secure private networking for database/storage/Key Vault

Public Ingress with DNS so users can access the app on a custom domain (blog.example.com)

The stack combines Terraform (for Azure infrastructure provisioning) and Kubernetes manifests (for application deployment).

2. Infrastructure with Terraform

Terraform is used to provision all required Azure resources.

🔹 Key Resources

Resource Group & Networking

Virtual Network (VNet) with subnets:

snet-aks: For AKS nodes

snet-priv: For private endpoints

AKS Cluster

System-assigned managed identity

System node pool (system) for core workloads

User node pool (usernp) with autoscaling enabled (min/max node count set via variables)

Azure Container Registry (ACR)

Stores container images (frontend, backend)

AKS identity has AcrPull role to pull images

Log Analytics

Centralized logging for AKS via OMS Agent

Azure SQL Database

Serverless database for blog data

Access via private endpoint and DNS zone

Key Vault

Secrets management

Private endpoint + DNS zone integration

Storage Account

For media (e.g., images in blog posts)



3. Kubernetes Setup

Once the infrastructure is provisioned, workloads are deployed into AKS.

🔹 Namespaces

All app workloads run inside blog-app namespace.

🔹 Backend

Deployment (backend.yaml)

Runs container image: <ACR_LOGIN>/backend:latest

Exposed as ClusterIP service on port 8080

🔹 Frontend

Deployment (frontend.yaml)

Runs container image: <ACR_LOGIN>/frontend:latest

Exposed as ClusterIP service on port 80

🔹 Ingress

Ingress resource (ingress.yaml)

Routes traffic from blog.example.com:

/api → backend service

/ → frontend service

Uses NGINX Ingress Controller

Works with ExternalDNS to automatically manage DNS records

🔹 ExternalDNS

Deployment (externalDNS.yaml)

Watches ingress resources

Creates/updates DNS records in Azure DNS Zone

Bound with proper RBAC for listing ingress/service resources

4. CI/CD Workflow

Build Docker images

docker build -t frontend:latest ./frontend
docker build -t backend:latest ./backend


Push to ACR

az acr login --name <acr_name>
docker tag frontend:latest <acr_name>.azurecr.io/frontend:latest
docker push <acr_name>.azurecr.io/frontend:latest
docker tag backend:latest <acr_name>.azurecr.io/backend:latest
docker push <acr_name>.azurecr.io/backend:latest


Deploy to AKS

kubectl apply -f backend.yaml
kubectl apply -f frontend.yaml
kubectl apply -f ingress.yaml
kubectl apply -f externalDNS.yaml
kubectl apply -f RBAC.yaml

5. Security & Networking

Private Endpoints: SQL, Key Vault, and Blob storage accessible only within VNet

Azure CNI + Calico: For network policies in AKS

TLS Certificates (can be added later using Cert-Manager with Let’s Encrypt)

6. Autoscaling

Cluster Autoscaler:

Configured in Terraform for usernp node pool

Automatically adds/removes worker nodes

Horizontal Pod Autoscaler (HPA) :

Could scale frontend/backend pods based on CPU/memory

7. Project Value

Infrastructure as Code → reproducible, version-controlled deployments

Separation of concerns → Terraform handles infra, Kubernetes manifests handle workloads

Scalability → both cluster and pods can scale automatically

Security → private networking, role-based access, ACR integration

Automation → DNS management with ExternalDNS, logging with Log Analytics

-–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
User Flow with Ingress + AAD

Now your website behind Ingress can be protected using oauth2-proxy with Azure AD (we already discussed this before).

Flow:

User browses → https://blog.example.com

Ingress → forwards request to oauth2-proxy

oauth2-proxy → redirects to Azure AD login

User signs in with AAD credentials

AAD issues token → oauth2-proxy validates

If valid, request continues to frontend/backend services

Kubernetes RBAC ensures user/group only has access to allowed resources



