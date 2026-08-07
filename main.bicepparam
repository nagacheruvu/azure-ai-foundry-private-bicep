using './main.bicep'

// ---------------------------------------------------------------------------
// Deployment suffix & environment
// ---------------------------------------------------------------------------
param suffix = 'kfpoc01'
param location = 'eastus2'
param environment = 'dev'

// ---------------------------------------------------------------------------
// Existing VNet/Subnet (same subscription as AI Foundry for KF)
// Replace with your actual resource IDs
// ---------------------------------------------------------------------------
param existingPeSubnetId = '/subscriptions/<AI-FOUNDRY-SUB-ID>/resourceGroups/<VNET-RG>/providers/Microsoft.Network/virtualNetworks/<VNET-NAME>/subnets/<PE-SUBNET-NAME>'
param existingComputeSubnetId = ''  // Optional: for compute injection

// ---------------------------------------------------------------------------
// Existing Private DNS Zone IDs
// Each zone can be in a DIFFERENT subscription/resource group
// e.g., storage zones in one sub, AML zones in another
// ---------------------------------------------------------------------------
param dnsZoneIdAml = '/subscriptions/<DNS-SUB-A>/resourceGroups/<DNS-RG-A>/providers/Microsoft.Network/privateDnsZones/privatelink.api.azureml.ms'
param dnsZoneIdNotebooks = '/subscriptions/<DNS-SUB-A>/resourceGroups/<DNS-RG-A>/providers/Microsoft.Network/privateDnsZones/privatelink.notebooks.azure.net'
param dnsZoneIdBlob = '/subscriptions/<DNS-SUB-B>/resourceGroups/<DNS-RG-B>/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
param dnsZoneIdFile = '/subscriptions/<DNS-SUB-B>/resourceGroups/<DNS-RG-B>/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net'
param dnsZoneIdKeyVault = '/subscriptions/<DNS-SUB-C>/resourceGroups/<DNS-RG-C>/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
param dnsZoneIdAcr = '/subscriptions/<DNS-SUB-B>/resourceGroups/<DNS-RG-B>/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
param dnsZoneIdOpenAi = '/subscriptions/<DNS-SUB-A>/resourceGroups/<DNS-RG-A>/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com'
param dnsZoneIdCognitiveServices = '/subscriptions/<DNS-SUB-A>/resourceGroups/<DNS-RG-A>/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'

// ---------------------------------------------------------------------------
// Existing Supporting Services (leave empty to create new)
// ---------------------------------------------------------------------------
param existingKeyVaultName = ''         // e.g., 'kv-myteam-prod'
param existingKeyVaultRg = ''
param existingStorageAccountName = ''   // e.g., 'stmyteamprod'
param existingStorageAccountRg = ''
param existingAcrName = ''              // e.g., 'crmyteamprod' (must be Premium SKU)
param existingAcrRg = ''
param existingLogAnalyticsName = ''     // e.g., 'law-central-prod'
param existingLogAnalyticsRg = ''

// ---------------------------------------------------------------------------
// Managed Network Isolation
// ---------------------------------------------------------------------------
param managedNetworkIsolationMode = 'AllowOnlyApprovedOutbound'  // Most secure: only approved PE + service tags

// ---------------------------------------------------------------------------
// Azure OpenAI
// ---------------------------------------------------------------------------
param deployAzureOpenAi = true
param existingOpenAiName = ''           // e.g., 'oai-shared-prod'
param existingOpenAiRg = ''
param openAiModelDeployments = [
  {
    name: 'gpt-51'
    model: 'gpt-5.1'
    version: '2025-11-13'
    capacity: 10
  }
  {
    name: 'text-embedding-3-large'
    model: 'text-embedding-3-large'
    version: '1'
    capacity: 10
  }
]
