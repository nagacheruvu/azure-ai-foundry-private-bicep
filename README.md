# AI Foundry Private Deployment (Hub-Spoke Model)

Production-ready Bicep modules to deploy Azure AI Foundry with **full private networking** using a hub-spoke topology — existing VNet and Private DNS Zones from a central networking subscription.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Central Networking Subscription                             │
│  ┌───────────────────┐  ┌─────────────────────────────────┐ │
│  │  VNet (Hub/Spoke) │  │  Private DNS Zones              │ │
│  │  ├─ snet-pe       │  │  - privatelink.api.azureml.ms   │ │
│  │  ├─ snet-compute  │  │  - privatelink.blob.core...     │ │
│  │  └─ snet-services │  │  - privatelink.openai.azure.com │ │
│  └───────────────────┘  │  - privatelink.vaultcore...     │ │
│                          │  - (+ 4 more)                   │ │
│                          └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │ Private Endpoints
┌─────────────────────────────────────────────────────────────┐
│  AI Foundry Subscription (this deployment)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  AI Hub      │  │  AI Project  │  │  Azure OpenAI│      │
│  │  (+ Hub PE)  │  │  (inherits)  │  │  (+ PE)      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Key Vault   │  │  Storage     │  │  ACR         │      │
│  │  (+ PE)      │  │  (+ blob/    │  │  (+ PE)      │      │
│  │              │  │    file PE)  │  │  Premium     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Run Prerequisites Check

```powershell
.\prereqs-check.ps1 `
  -PeSubnetId "/subscriptions/<NET-SUB>/resourceGroups/<NET-RG>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/<PE-SUBNET>" `
  -DnsSubscriptionId "<DNS-SUB-ID>" `
  -DnsResourceGroup "<DNS-RG>" `
  -TargetSubscriptionId "<AI-SUB-ID>" `
  -TargetResourceGroup "rg-aifoundry-prod"
```

The script validates:
1. Azure CLI & Bicep installed
2. Subscription access (target + networking)
3. Resource provider registration
4. VNet/Subnet config (PE policies, IP capacity)
5. All 8 Private DNS Zones exist with VNet links
6. Existing resources (if specified) are valid
7. RBAC permissions for cross-sub PE creation

### 2. Configure Parameters

Edit `main.bicepparam` with your environment values:
- Central VNet subnet IDs
- Private DNS Zone resource IDs
- Existing resource names (or leave empty to create new)

### 3. Deploy

```bash
az group create --name rg-aifoundry-prod --location eastus2

az deployment group create \
  --resource-group rg-aifoundry-prod \
  --template-file main.bicep \
  --parameters main.bicepparam
```

## Modules

| Module | Purpose |
|--------|---------|
| `modules/ai-foundry.bicep` | AI Foundry Hub + Project + Hub PE |
| `modules/azure-openai.bicep` | Azure OpenAI + model deployments + PE |
| `modules/supporting-services.bicep` | Key Vault, Storage, ACR, App Insights (conditional) |
| `modules/network.bicep` | VNet + Subnets (greenfield only) |
| `modules/private-dns.bicep` | DNS Zones + VNet links (greenfield only) |

## Key Features

- **Hub-spoke compatible** — uses existing centralized VNet and DNS
- **Conditional resource creation** — pass existing resource names or create new
- **Cross-subscription** — PE subnet and DNS zones can be in different subscriptions
- **All public access disabled** — every resource locked to private endpoints
- **Managed network isolation** — AI Foundry Hub uses `AllowInternetOutbound` mode
- **Azure OpenAI** — optional deployment with GPT-4o and embeddings, private endpoint
- **Prerequisites validation** — comprehensive PowerShell script catches misconfigs early

## Requirements

- Azure CLI 2.50+
- Bicep CLI 0.22+
- Contributor on target subscription
- Network Contributor on networking subscription (for cross-sub PE creation)
- Private DNS Zone Contributor on DNS resource group

## License

Internal Microsoft use. Adapt for customer engagements.
