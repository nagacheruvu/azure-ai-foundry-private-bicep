# Prerequisites Guide — AI Foundry Private Deployment

This guide covers everything required before deploying AI Foundry with private networking in a hub-spoke topology. Use either the **automated script** or the **manual portal** path.

---

## Overview

The deployment assumes a **hub-spoke model** where:

- **Central/Hub subscription** owns the VNet and Private DNS Zones
- **Spoke subscription** hosts AI Foundry, OpenAI, and supporting services
- Private Endpoints in the spoke connect back to the hub VNet
- DNS A-records auto-register in central Private DNS Zones

```
Central Subscription                    Spoke Subscription
┌─────────────────────┐                ┌─────────────────────┐
│  VNet               │◄── PE NICs ────│  AI Foundry Hub     │
│  Private DNS Zones  │                │  Azure OpenAI       │
│  (linked to VNet)   │                │  Key Vault          │
└─────────────────────┘                │  Storage / ACR      │
                                       └─────────────────────┘
```

---

## Pre-Requisite Checklist

| # | Requirement | Why | Automated Check |
|---|-------------|-----|-----------------|
| 1 | Azure CLI 2.50+ with Bicep | Deployment tooling | ✅ |
| 2 | Access to target (spoke) subscription | Deploy AI Foundry resources | ✅ |
| 3 | Access to networking (hub) subscription | Cross-sub PE creation | ✅ |
| 4 | Resource providers registered | ARM can create resources | ✅ |
| 5 | VNet with PE subnet (policies disabled) | Private endpoints need this | ✅ |
| 6 | 8 Private DNS Zones with VNet links | PE DNS resolution | ✅ |
| 7 | RBAC: Contributor on spoke sub | Create AI Foundry resources | ✅ |
| 8 | RBAC: Network Contributor on hub sub | Create PEs in cross-sub VNet | ✅ |
| 9 | RBAC: Private DNS Zone Contributor | Auto-register A-records | ✅ |
| 10 | Existing resources valid (if reusing) | Correct SKU, config | ✅ |

---

## Option A: Automated Script

### Run the Prerequisites Check

```powershell
.\prereqs-check.ps1 `
  -PeSubnetId "/subscriptions/<HUB-SUB-ID>/resourceGroups/<HUB-RG>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/<PE-SUBNET>" `
  -DnsSubscriptionId "<HUB-SUB-ID>" `
  -DnsResourceGroup "<DNS-RG-NAME>" `
  -TargetSubscriptionId "<SPOKE-SUB-ID>" `
  -TargetResourceGroup "<SPOKE-RG-NAME>" `
  -Location "eastus2"
```

#### Optional Parameters

```powershell
  -ComputeSubnetId "/subscriptions/.../subnets/snet-compute"   # If using compute injection
  -ExistingKeyVaultName "kv-myteam-prod"                       # If reusing KV
  -ExistingStorageAccountName "stmyteamprod"                   # If reusing Storage
  -ExistingAcrName "crmyteamprod"                              # If reusing ACR
```

#### Interpreting Results

| Symbol | Meaning | Action |
|--------|---------|--------|
| `[PASS]` | Requirement met | None |
| `[WARN]` | Non-blocking issue | Review before deploying |
| `[FAIL]` | Blocking issue | Must fix before deploying |

The script outputs DNS Zone resource IDs at the end — copy these into your `main.bicepparam` file.

---

## Option B: Manual Portal Path

### Step 1 — Verify Azure CLI & Bicep

```bash
# Check CLI version (need 2.50+)
az version

# Check Bicep (need 0.22+)
az bicep version

# If Bicep missing:
az bicep install
```

---

### Step 2 — Verify Subscription Access

1. Go to **Azure Portal** → **Subscriptions**
2. Confirm you can see both:
   - **Hub/Networking subscription** (where VNet + DNS live)
   - **Spoke subscription** (where AI Foundry will deploy)
3. CLI equivalent:
   ```bash
   az account list --query "[].{Name:name, Id:id}" -o table
   ```

---

### Step 3 — Register Resource Providers

In the **spoke subscription**, ensure these providers are registered:

| Provider | Purpose |
|----------|---------|
| `Microsoft.MachineLearningServices` | AI Foundry Hub + Project |
| `Microsoft.CognitiveServices` | Azure OpenAI |
| `Microsoft.Network` | Private Endpoints, NICs |
| `Microsoft.Storage` | Storage Account |
| `Microsoft.KeyVault` | Key Vault |
| `Microsoft.ContainerRegistry` | Container Registry |
| `Microsoft.Insights` | Application Insights |
| `Microsoft.OperationalInsights` | Log Analytics |

**Portal path:**
1. **Subscriptions** → select spoke subscription → **Resource providers**
2. Search each provider and click **Register** if status is `NotRegistered`

**CLI path:**
```bash
az provider register --namespace Microsoft.MachineLearningServices --subscription <SPOKE-SUB-ID>
az provider register --namespace Microsoft.CognitiveServices --subscription <SPOKE-SUB-ID>
az provider register --namespace Microsoft.Network --subscription <SPOKE-SUB-ID>
az provider register --namespace Microsoft.Storage --subscription <SPOKE-SUB-ID>
az provider register --namespace Microsoft.KeyVault --subscription <SPOKE-SUB-ID>
az provider register --namespace Microsoft.ContainerRegistry --subscription <SPOKE-SUB-ID>
az provider register --namespace Microsoft.Insights --subscription <SPOKE-SUB-ID>
az provider register --namespace Microsoft.OperationalInsights --subscription <SPOKE-SUB-ID>
```

---

### Step 4 — VNet & Subnet Configuration

#### 4a. Verify the PE Subnet Exists

**Portal path:**
1. Go to **Virtual Networks** in the hub subscription
2. Select your VNet → **Subnets**
3. Verify a subnet exists for private endpoints (e.g., `snet-pe`)

#### 4b. Disable Private Endpoint Network Policies

This is **critical** — private endpoints will fail to create if this is not set.

**Portal path:**
1. **Virtual Networks** → your VNet → **Subnets** → select PE subnet
2. Under **Private endpoint network policy**, set to **Disabled**
3. Click **Save**

**CLI path:**
```bash
az network vnet subnet update \
  --ids "/subscriptions/<HUB-SUB>/resourceGroups/<HUB-RG>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/<PE-SUBNET>" \
  --private-endpoint-network-policies Disabled
```

#### 4c. Verify IP Capacity

The PE subnet needs at least **15 available IPs** for the deployment:

| Resource | IPs Needed |
|----------|-----------|
| AI Hub PE | 3 (workspace, inference, models) |
| Azure OpenAI PE | 1 |
| Key Vault PE | 1 |
| Storage Blob PE | 1 |
| Storage File PE | 1 |
| ACR PE | 2 (registry + data) |
| Azure reserved | 5 |
| **Total minimum** | **~15** |

A `/27` (32 IPs) is the minimum; `/24` (256 IPs) is recommended.

---

### Step 5 — Private DNS Zones

#### 5a. Create Required DNS Zones

All 8 zones must exist in the hub/central subscription:

| DNS Zone | Used By |
|----------|---------|
| `privatelink.api.azureml.ms` | AI Foundry Hub/Project |
| `privatelink.notebooks.azure.net` | AI Foundry Notebooks |
| `privatelink.blob.core.windows.net` | Storage (blob) |
| `privatelink.file.core.windows.net` | Storage (file) |
| `privatelink.vaultcore.azure.net` | Key Vault |
| `privatelink.azurecr.io` | Container Registry |
| `privatelink.openai.azure.com` | Azure OpenAI |
| `privatelink.cognitiveservices.azure.com` | Cognitive Services |

**Portal path:**
1. **Private DNS Zones** → **+ Create**
2. Select the hub subscription and DNS resource group
3. Enter the zone name (e.g., `privatelink.api.azureml.ms`)
4. Repeat for all 8 zones

**CLI path:**
```bash
HUB_SUB="<HUB-SUB-ID>"
DNS_RG="<DNS-RG-NAME>"

zones=(
  "privatelink.api.azureml.ms"
  "privatelink.notebooks.azure.net"
  "privatelink.blob.core.windows.net"
  "privatelink.file.core.windows.net"
  "privatelink.vaultcore.azure.net"
  "privatelink.azurecr.io"
  "privatelink.openai.azure.com"
  "privatelink.cognitiveservices.azure.com"
)

for zone in "${zones[@]}"; do
  az network private-dns zone create \
    --subscription $HUB_SUB \
    --resource-group $DNS_RG \
    --name $zone
done
```

#### 5b. Link DNS Zones to the VNet

Each DNS zone must be linked to the VNet so that resources in the VNet can resolve private endpoint addresses.

**Portal path:**
1. **Private DNS Zones** → select a zone → **Virtual network links**
2. Click **+ Add**
3. Name: `<vnet-name>-link`
4. Virtual network: select your hub VNet
5. Enable auto registration: **No** (not needed for PE DNS)
6. Repeat for all 8 zones

**CLI path:**
```bash
VNET_ID="/subscriptions/$HUB_SUB/resourceGroups/<HUB-RG>/providers/Microsoft.Network/virtualNetworks/<VNET-NAME>"

for zone in "${zones[@]}"; do
  az network private-dns link vnet create \
    --subscription $HUB_SUB \
    --resource-group $DNS_RG \
    --zone-name $zone \
    --name "<VNET-NAME>-link" \
    --virtual-network $VNET_ID \
    --registration-enabled false
done
```

#### 5c. Collect DNS Zone Resource IDs

You'll need these for the deployment parameters:

```bash
for zone in "${zones[@]}"; do
  echo "$zone:"
  echo "  /subscriptions/$HUB_SUB/resourceGroups/$DNS_RG/providers/Microsoft.Network/privateDnsZones/$zone"
done
```

---

### Step 6 — RBAC Permissions

Three roles are needed across the two subscriptions:

#### 6a. Contributor on Spoke Subscription

Allows creating AI Foundry, OpenAI, KV, Storage, ACR resources.

**Portal path:**
1. **Subscriptions** → spoke subscription → **Access control (IAM)**
2. **+ Add role assignment** → Role: `Contributor`
3. Assign to your deploying identity (user or service principal)

#### 6b. Network Contributor on Hub Subscription (or VNet scope)

Allows creating Private Endpoint NICs in the hub VNet subnet.

**Portal path:**
1. **Subscriptions** → hub subscription → **Access control (IAM)**
   - Or scope to the VNet: **Virtual Networks** → your VNet → **Access control (IAM)**
2. **+ Add role assignment** → Role: `Network Contributor`
3. Assign to your deploying identity

#### 6c. Private DNS Zone Contributor on DNS Resource Group

Allows the PE DNS Zone Groups to auto-register A-records.

**Portal path:**
1. **Resource Groups** → DNS resource group → **Access control (IAM)**
2. **+ Add role assignment** → Role: `Private DNS Zone Contributor`
3. Assign to your deploying identity

**CLI path (all three):**
```bash
DEPLOYER_ID=$(az ad signed-in-user show --query id -o tsv)

# Contributor on spoke
az role assignment create \
  --assignee $DEPLOYER_ID \
  --role "Contributor" \
  --scope "/subscriptions/<SPOKE-SUB-ID>"

# Network Contributor on hub VNet
az role assignment create \
  --assignee $DEPLOYER_ID \
  --role "Network Contributor" \
  --scope "/subscriptions/<HUB-SUB-ID>/resourceGroups/<HUB-RG>/providers/Microsoft.Network/virtualNetworks/<VNET>"

# Private DNS Zone Contributor on DNS RG
az role assignment create \
  --assignee $DEPLOYER_ID \
  --role "Private DNS Zone Contributor" \
  --scope "/subscriptions/<HUB-SUB-ID>/resourceGroups/<DNS-RG>"
```

---

### Step 7 — Validate Existing Resources (if reusing)

If passing existing resource names instead of creating new:

| Resource | Requirements |
|----------|-------------|
| **Key Vault** | RBAC authorization enabled; deployer needs `Key Vault Administrator` |
| **Storage Account** | StorageV2, non-HNS (no Data Lake); Standard_LRS or higher |
| **Container Registry** | **Premium SKU required** (only Premium supports private endpoints) |
| **Log Analytics** | Any tier; used for Application Insights backing store |

**Portal validation:**
1. **Key Vaults** → your KV → **Properties** → verify "Permission model" = `Azure role-based access control`
2. **Container Registries** → your ACR → **Overview** → verify SKU = `Premium`
3. **Storage Accounts** → your storage → **Overview** → verify Kind = `StorageV2`

---

## Collecting Parameters for Deployment

After completing all prerequisites, fill in `main.bicepparam`:

| Parameter | Where to Find | Default |
|-----------|---------------|---------|
| `suffix` | Your naming convention (3-8 chars) | — |
| `environment` | `dev`, `test`, or `prod` | `dev` |
| `managedNetworkIsolationMode` | Security requirement | `AllowOnlyApprovedOutbound` |
| `existingPeSubnetId` | Portal: VNet → Subnets → PE subnet → Properties → Resource ID | — |
| `dnsZoneId*` | Portal: Private DNS Zone → Properties → Resource ID | — |
| `existingKeyVaultName` | Portal: Key Vault → Overview → Name (or leave empty) | `''` |
| `existingStorageAccountName` | Portal: Storage Account → Overview → Name (or leave empty) | `''` |
| `existingAcrName` | Portal: Container Registry → Overview → Name (or leave empty) | `''` |
| `deployAzureOpenAi` | Whether to deploy Azure OpenAI | `true` |
| `openAiModelDeployments` | Models to deploy (array) | GPT-5.1 + embeddings |

### Managed Network Isolation Modes

| Mode | Description |
|------|-------------|
| **`AllowOnlyApprovedOutbound`** (default) | Most secure — only approved private endpoints and required Azure service tags. No internet access from compute. |
| `AllowInternetOutbound` | Private endpoints + unrestricted internet egress. Use for dev/test when pip/conda/HuggingFace access is needed. |

---

## Troubleshooting Common Issues

### "FlagMustBeSetForRestore" — Soft-deleted resource conflict

A previously deleted Cognitive Services or Key Vault with the same name exists in soft-delete.

**Fix:**
```bash
# Purge soft-deleted OpenAI account
az cognitiveservices account purge \
  --name <ACCOUNT-NAME> \
  --resource-group <RG> \
  --location <REGION>

# Purge soft-deleted Key Vault
az keyvault purge --name <VAULT-NAME> --location <REGION>
```

### "PUT PE operation should be performed on the hub"

You cannot create a private endpoint directly on an AI Foundry **Project** — only on the **Hub**. Projects inherit networking from their parent Hub. This module handles this correctly.

### "privateEndpointNetworkPolicies must be Disabled"

The PE subnet hasn't been configured. Run:
```bash
az network vnet subnet update --ids <SUBNET-ID> --private-endpoint-network-policies Disabled
```

### Private endpoint stuck in "Pending" state

The deploying identity lacks `Network Contributor` on the VNet/subnet. Add the role assignment per Step 6b.

### DNS resolution failing (can't reach private endpoint)

1. Verify the DNS zone exists and matches the service (e.g., `privatelink.vaultcore.azure.net` for Key Vault)
2. Verify the VNet link exists on the DNS zone
3. Verify the A-record was created (Portal: DNS Zone → Record sets)

---

## Next Steps

Once all prerequisites are confirmed:

```bash
# Create the spoke resource group
az group create --name <SPOKE-RG> --location eastus2

# Deploy
az deployment group create \
  --resource-group <SPOKE-RG> \
  --template-file main.bicep \
  --parameters main.bicepparam
```

Deployment takes approximately 8-12 minutes.
