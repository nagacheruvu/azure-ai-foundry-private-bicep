# AI Foundry Private Deployment

Production-ready Bicep modules to deploy Azure AI Foundry with **full private networking**. Supports flexible topologies — VNet in same or different subscription, DNS zones spread across **multiple subscriptions**. No temporary DNS zone workaround needed.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  Subscription A — AI Foundry + VNet                   │
│  ┌───────────────────┐  ┌──────────────────────────┐ │
│  │  VNet             │  │  AI Foundry Hub + Project │ │
│  │  ├─ snet-pe       │  │  Azure OpenAI            │ │
│  │  ├─ snet-compute  │  │  Key Vault / Storage     │ │
│  │  └─ snet-services │  │  ACR / App Insights      │ │
│  └───────────────────┘  └──────────────────────────┘ │
└──────────────────────────────────────────────────────┘
         ▲ VNet links              ▲ PE DNS Zone Groups
┌────────┴──────────────────────────┴──────────────────┐
│  Subscription B, C, ... — Private DNS Zones           │
│  ┌───────────────────────────────────────────────┐   │
│  │  privatelink.api.azureml.ms         (Sub B)   │   │
│  │  privatelink.blob.core.windows.net  (Sub C)   │   │
│  │  privatelink.vaultcore.azure.net    (Sub B)   │   │
│  │  privatelink.openai.azure.com       (Sub C)   │   │
│  │  ... (8 zones, any sub/RG mix)                │   │
│  └───────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
```

DNS zones can be in **one or more separate subscriptions** — each zone 
is referenced by full resource ID. No temp zone workaround needed.

## Quick Start

### 1. Run Prerequisites Check

**DNS zones in multiple subscriptions (recommended for KF):**

```powershell
$dnsZones = @{
  aml               = "/subscriptions/SUB-B/resourceGroups/rg-dns-aml/providers/Microsoft.Network/privateDnsZones/privatelink.api.azureml.ms"
  notebooks         = "/subscriptions/SUB-B/resourceGroups/rg-dns-aml/providers/Microsoft.Network/privateDnsZones/privatelink.notebooks.azure.net"
  blob              = "/subscriptions/SUB-C/resourceGroups/rg-dns-storage/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
  file              = "/subscriptions/SUB-C/resourceGroups/rg-dns-storage/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"
  keyVault          = "/subscriptions/SUB-B/resourceGroups/rg-dns-kv/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
  acr               = "/subscriptions/SUB-C/resourceGroups/rg-dns-storage/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
  openai            = "/subscriptions/SUB-B/resourceGroups/rg-dns-ai/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com"
  cognitiveServices = "/subscriptions/SUB-B/resourceGroups/rg-dns-ai/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com"
}

.\prereqs-check.ps1 `
  -PeSubnetId "/subscriptions/<SUB-A>/.../subnets/<PE-SUBNET>" `
  -DnsZoneIds $dnsZones `
  -TargetSubscriptionId "<SUB-A>" `
  -TargetResourceGroup "rg-aifoundry-prod"
```

**All DNS in one sub/RG (shorthand):**

```powershell
.\prereqs-check.ps1 `
  -PeSubnetId "/subscriptions/<SUB-A>/.../subnets/<PE-SUBNET>" `
  -DnsSubscriptionId "<DNS-SUB>" `
  -DnsResourceGroup "<DNS-RG>" `
  -TargetSubscriptionId "<SUB-A>" `
  -TargetResourceGroup "rg-aifoundry-prod"
```

The script validates:
1. Azure CLI & Bicep installed
2. Subscription access (target + all DNS subscriptions)
3. Resource provider registration
4. VNet/Subnet config (PE policies, IP capacity)
5. All 8 Private DNS Zones exist with VNet links (across any number of subs)
6. Existing resources (if specified) are valid
7. RBAC permissions per DNS subscription/RG

### 2. Configure Parameters

Edit `main.bicepparam` with your environment values:
- VNet subnet ID (same or different subscription)
- Private DNS Zone resource IDs (each can be in a different sub/RG)
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

- **Flexible topology** — VNet in same or different subscription from AI Foundry
- **Multi-subscription DNS** — DNS zones can be spread across multiple subscriptions/RGs
- **AllowOnlyApprovedOutbound** — most restrictive isolation; no internet egress, only approved PE + service tags
- **Conditional resource creation** — pass existing resource names or create new
- **Cross-subscription** — PE subnet and DNS zones can be in different subscriptions
- **All public access disabled** — every resource locked to private endpoints
- **Azure OpenAI** — optional deployment with GPT-5.1 and embeddings, private endpoint auto-registered as approved outbound
- **Prerequisites validation** — comprehensive PowerShell script catches misconfigs early

## Managed Network Isolation Modes

| Mode | Outbound Behavior | Use Case |
|------|-------------------|----------|
| `AllowOnlyApprovedOutbound` **(default)** | Only approved PEs + required service tags | Production / regulated workloads |
| `AllowInternetOutbound` | PEs + unrestricted internet | Dev/test or when pip/conda needed |

With `AllowOnlyApprovedOutbound`, the system auto-creates:
- **Required PE rules**: Storage (blob/file), Key Vault, ACR, Workspace
- **Required ServiceTag rules**: AAD, AzureML, ARM, AzureMonitor, BatchNodeManagement, MCR, VirtualNetwork, AzureFrontDoor
- **UserDefined PE rule**: OpenAI account (added by this Bicep)

Set `managedNetworkIsolationMode` in your parameters to switch modes.

## Requirements

- Azure CLI 2.50+
- Bicep CLI 0.22+
- Contributor on target subscription
- Network Contributor on VNet subscription (if cross-sub)
- Private DNS Zone Contributor on **each** DNS subscription/RG

## License

Internal Microsoft use. Adapt for customer engagements.
