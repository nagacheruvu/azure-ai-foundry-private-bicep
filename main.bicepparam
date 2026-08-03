using './main.bicep'

// ---------------------------------------------------------------------------
// Deployment suffix & environment
// ---------------------------------------------------------------------------
param suffix = 'kfpoc01'
param location = 'eastus2'
param environment = 'dev'

// ---------------------------------------------------------------------------
// Existing VNet/Subnet from central networking subscription
// Replace with your actual resource IDs
// ---------------------------------------------------------------------------
param existingPeSubnetId = '/subscriptions/<NETWORK-SUB-ID>/resourceGroups/<NETWORK-RG>/providers/Microsoft.Network/virtualNetworks/<VNET-NAME>/subnets/<PE-SUBNET-NAME>'
param existingComputeSubnetId = ''  // Optional: for compute injection

// ---------------------------------------------------------------------------
// Existing Private DNS Zone IDs from central subscription
// Replace with your actual DNS zone resource IDs
// ---------------------------------------------------------------------------
param dnsZoneIdAml = '/subscriptions/<DNS-SUB-ID>/resourceGroups/<DNS-RG>/providers/Microsoft.Network/privateDnsZones/privatelink.api.azureml.ms'
param dnsZoneIdNotebooks = '/subscriptions/<DNS-SUB-ID>/resourceGroups/<DNS-RG>/providers/Microsoft.Network/privateDnsZones/privatelink.notebooks.azure.net'
param dnsZoneIdBlob = '/subscriptions/<DNS-SUB-ID>/resourceGroups/<DNS-RG>/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
param dnsZoneIdFile = '/subscriptions/<DNS-SUB-ID>/resourceGroups/<DNS-RG>/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net'
param dnsZoneIdKeyVault = '/subscriptions/<DNS-SUB-ID>/resourceGroups/<DNS-RG>/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
param dnsZoneIdAcr = '/subscriptions/<DNS-SUB-ID>/resourceGroups/<DNS-RG>/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
param dnsZoneIdOpenAi = '/subscriptions/<DNS-SUB-ID>/resourceGroups/<DNS-RG>/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com'
param dnsZoneIdCognitiveServices = '/subscriptions/<DNS-SUB-ID>/resourceGroups/<DNS-RG>/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'

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
// Azure OpenAI
// ---------------------------------------------------------------------------
param deployAzureOpenAi = true
param existingOpenAiName = ''           // e.g., 'oai-shared-prod'
param existingOpenAiRg = ''
param openAiModelDeployments = [
  {
    name: 'gpt-4o'
    model: 'gpt-4o'
    version: '2024-08-06'
    capacity: 10
  }
  {
    name: 'text-embedding-ada-002'
    model: 'text-embedding-ada-002'
    version: '2'
    capacity: 10
  }
]
