// ============================================================================
// AI Foundry - Private Deployment (Flexible Topology)
// Supports:
//   - VNet in same subscription as AI Foundry (KF pattern)
//   - DNS Zones spread across one or more separate subscriptions
//   - Existing supporting services in any subscription/RG
// ============================================================================

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Required Parameters
// ---------------------------------------------------------------------------

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Workload or project short name for CAF naming (e.g., "kf", "contoso")')
@minLength(2)
@maxLength(10)
param workloadName string

@description('Environment (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Azure region short name for CAF naming (e.g., "eus2" for eastus2)')
param regionShortName string = 'eus2'

@description('Instance number for uniqueness')
param instance string = '001'

// ---------------------------------------------------------------------------
// Name Overrides (leave empty to use CAF defaults)
// ---------------------------------------------------------------------------

@description('Override: AI Foundry Hub name (default CAF: hub-{workload}-{env}-{region}-{instance})')
param hubNameOverride string = ''

@description('Override: AI Foundry Project name (default CAF: proj-{workload}-{env}-{region}-{instance})')
param projectNameOverride string = ''

@description('Override: Azure OpenAI name (default CAF: oai-{workload}-{env}-{region}-{instance})')
param openAiNameOverride string = ''

@description('Override: Key Vault name (default CAF: kv-{workload}-{env}-{region}-{instance})')
param keyVaultNameOverride string = ''

@description('Override: Storage Account name (default CAF: st{workload}{env}{region}{instance})')
param storageNameOverride string = ''

@description('Override: Container Registry name (default CAF: cr{workload}{env}{region}{instance})')
param acrNameOverride string = ''

@description('Override: Log Analytics name (default CAF: log-{workload}-{env}-{region}-{instance})')
param logAnalyticsNameOverride string = ''

@description('Override: App Insights name (default CAF: appi-{workload}-{env}-{region}-{instance})')
param appInsightsNameOverride string = ''

// ---------------------------------------------------------------------------
// CAF Naming Module
// ---------------------------------------------------------------------------

module naming 'modules/naming.bicep' = {
  name: 'deploy-naming'
  params: {
    workloadName: workloadName
    environment: environment
    regionShortName: regionShortName
    instance: instance
    hubNameOverride: hubNameOverride
    projectNameOverride: projectNameOverride
    openAiNameOverride: openAiNameOverride
    keyVaultNameOverride: keyVaultNameOverride
    storageNameOverride: storageNameOverride
    acrNameOverride: acrNameOverride
    logAnalyticsNameOverride: logAnalyticsNameOverride
    appInsightsNameOverride: appInsightsNameOverride
  }
}

// ---------------------------------------------------------------------------
// Existing VNet/Subnet (can be same or different subscription)
// ---------------------------------------------------------------------------

@description('Resource ID of the existing subnet for private endpoints')
param existingPeSubnetId string

@description('Resource ID of the existing subnet for AI Foundry compute injection (optional)')
param existingComputeSubnetId string = ''

// ---------------------------------------------------------------------------
// Existing Private DNS Zone IDs
// Each zone can be in a DIFFERENT subscription/RG — pass full resource IDs
// e.g., /subscriptions/<SUB-A>/resourceGroups/<RG-1>/providers/Microsoft.Network/privateDnsZones/...
// ---------------------------------------------------------------------------

@description('Resource ID of privatelink.api.azureml.ms DNS zone')
param dnsZoneIdAml string

@description('Resource ID of privatelink.notebooks.azure.net DNS zone')
param dnsZoneIdNotebooks string

@description('Resource ID of privatelink.blob.core.windows.net DNS zone')
param dnsZoneIdBlob string

@description('Resource ID of privatelink.file.core.windows.net DNS zone')
param dnsZoneIdFile string

@description('Resource ID of privatelink.vaultcore.azure.net DNS zone')
param dnsZoneIdKeyVault string

@description('Resource ID of privatelink.azurecr.io DNS zone')
param dnsZoneIdAcr string

@description('Resource ID of privatelink.openai.azure.com DNS zone')
param dnsZoneIdOpenAi string

@description('Resource ID of privatelink.cognitiveservices.azure.com DNS zone')
param dnsZoneIdCognitiveServices string

// ---------------------------------------------------------------------------
// Existing Supporting Services (optional - leave empty to create new)
// ---------------------------------------------------------------------------

@description('Name of existing Key Vault (leave empty to create new)')
param existingKeyVaultName string = ''

@description('Resource group of existing Key Vault')
param existingKeyVaultRg string = resourceGroup().name

@description('Name of existing Storage Account (leave empty to create new)')
param existingStorageAccountName string = ''

@description('Resource group of existing Storage Account')
param existingStorageAccountRg string = resourceGroup().name

@description('Name of existing Container Registry (leave empty to create new)')
param existingAcrName string = ''

@description('Resource group of existing ACR')
param existingAcrRg string = resourceGroup().name

@description('Name of existing Log Analytics Workspace (leave empty to create new)')
param existingLogAnalyticsName string = ''

@description('Resource group of existing Log Analytics workspace')
param existingLogAnalyticsRg string = resourceGroup().name

// ---------------------------------------------------------------------------
// Derived variables
// ---------------------------------------------------------------------------

var dnsZoneIds = {
  aml: dnsZoneIdAml
  notebooks: dnsZoneIdNotebooks
  blob: dnsZoneIdBlob
  file: dnsZoneIdFile
  keyVault: dnsZoneIdKeyVault
  acr: dnsZoneIdAcr
  openai: dnsZoneIdOpenAi
  cognitiveServices: dnsZoneIdCognitiveServices
}

var createKeyVault = empty(existingKeyVaultName)
var createStorage = empty(existingStorageAccountName)
var createAcr = empty(existingAcrName)
var createLogAnalytics = empty(existingLogAnalyticsName)

// ---------------------------------------------------------------------------
// Existing resource references (cross-RG)
// ---------------------------------------------------------------------------

resource existingKv 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (!createKeyVault) {
  name: existingKeyVaultName
  scope: resourceGroup(existingKeyVaultRg)
}

resource existingStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = if (!createStorage) {
  name: existingStorageAccountName
  scope: resourceGroup(existingStorageAccountRg)
}

resource existingAcrRef 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = if (!createAcr) {
  name: existingAcrName
  scope: resourceGroup(existingAcrRg)
}

resource existingLaw 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = if (!createLogAnalytics) {
  name: existingLogAnalyticsName
  scope: resourceGroup(existingLogAnalyticsRg)
}

// ---------------------------------------------------------------------------
// New Supporting Services (only created when existing not specified)
// ---------------------------------------------------------------------------

module newServices 'modules/supporting-services.bicep' = {
  name: 'deploy-supporting-services'
  params: {
    location: location
    peSubnetId: existingPeSubnetId
    dnsZoneIds: dnsZoneIds
    createKeyVault: createKeyVault
    createStorage: createStorage
    createAcr: createAcr
    createLogAnalytics: createLogAnalytics
    keyVaultName: naming.outputs.keyVaultName
    storageName: naming.outputs.storageName
    acrName: naming.outputs.acrName
    logAnalyticsName: naming.outputs.logAnalyticsName
    appInsightsName: naming.outputs.appInsightsName
    pepSuffix: naming.outputs.pepSuffix
  }
}

// ---------------------------------------------------------------------------
// AI Foundry Hub + Project with Private Endpoint
// ---------------------------------------------------------------------------

@description('Managed network isolation mode for AI Foundry Hub')
@allowed(['AllowInternetOutbound', 'AllowOnlyApprovedOutbound'])
param managedNetworkIsolationMode string = 'AllowOnlyApprovedOutbound'

@description('Deploy Azure OpenAI account (set false to skip)')
param deployAzureOpenAi bool = true

@description('Name of existing Azure OpenAI account (leave empty to create new)')
param existingOpenAiName string = ''

@description('Resource group of existing Azure OpenAI account')
param existingOpenAiRg string = resourceGroup().name

@description('Model deployments for new Azure OpenAI account')
param openAiModelDeployments array = [
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

var createOpenAi = deployAzureOpenAi && empty(existingOpenAiName)

resource existingOpenAiRef 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = if (!createOpenAi && !empty(existingOpenAiName)) {
  name: existingOpenAiName
  scope: resourceGroup(existingOpenAiRg)
}

// ---------------------------------------------------------------------------
// 4. Azure OpenAI with Private Endpoint (deploys before Hub for outbound rule)
// ---------------------------------------------------------------------------

module azureOpenAi 'modules/azure-openai.bicep' = if (createOpenAi) {
  name: 'deploy-azure-openai'
  params: {
    location: location
    peSubnetId: existingPeSubnetId
    dnsZoneIds: dnsZoneIds
    openAiName: naming.outputs.openAiName
    pepSuffix: naming.outputs.pepSuffix
    modelDeployments: openAiModelDeployments
  }
}

// Resolve OpenAI account ID for the Hub managed network outbound rule
var openAiAccountId = createOpenAi ? azureOpenAi!.outputs.openAiAccountId : (!empty(existingOpenAiName) ? existingOpenAiRef.id : '')

// ---------------------------------------------------------------------------
// 5. AI Foundry Hub + Project (depends on OpenAI for outbound rule)
// ---------------------------------------------------------------------------

module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'deploy-ai-foundry'
  params: {
    location: location
    peSubnetId: existingPeSubnetId
    computeSubnetId: existingComputeSubnetId
    keyVaultId: createKeyVault ? newServices.outputs.keyVaultId : existingKv.id
    storageAccountId: createStorage ? newServices.outputs.storageAccountId : existingStorage.id
    containerRegistryId: createAcr ? newServices.outputs.containerRegistryId : existingAcrRef.id
    appInsightsId: newServices.outputs.appInsightsId
    dnsZoneIds: dnsZoneIds
    managedNetworkIsolationMode: managedNetworkIsolationMode
    openAiAccountId: openAiAccountId
    hubName: naming.outputs.hubName
    projectName: naming.outputs.projectName
    pepSuffix: naming.outputs.pepSuffix
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output openAiEndpoint string = createOpenAi ? azureOpenAi!.outputs.openAiEndpoint : ''
output openAiAccountName string = createOpenAi ? azureOpenAi!.outputs.openAiAccountName : existingOpenAiName
output aiHubName string = aiFoundry.outputs.hubName
output aiHubId string = aiFoundry.outputs.hubId
output aiProjectName string = aiFoundry.outputs.projectName
output aiProjectId string = aiFoundry.outputs.projectId
output hubPrincipalId string = aiFoundry.outputs.hubPrincipalId
output projectPrincipalId string = aiFoundry.outputs.projectPrincipalId
output keyVaultName string = createKeyVault ? newServices.outputs.keyVaultNameOut : existingKeyVaultName
output storageAccountName string = createStorage ? newServices.outputs.storageAccountNameOut : existingStorageAccountName
output acrName string = createAcr ? newServices.outputs.acrNameOut : existingAcrName
