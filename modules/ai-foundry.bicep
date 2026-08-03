// ============================================================================
// Module: ai-foundry.bicep
// AI Foundry Hub + Project with private endpoint (Hub only)
// ============================================================================

@description('Azure region')
param location string

@description('Resource name suffix')
param suffix string

@description('Environment label')
param environment string = 'dev'

@description('Subnet ID for private endpoints')
param peSubnetId string

@description('Subnet ID for compute injection (optional)')
param computeSubnetId string = ''

@description('Key Vault resource ID')
param keyVaultId string

@description('Storage Account resource ID')
param storageAccountId string

@description('Container Registry resource ID')
param containerRegistryId string

@description('Application Insights resource ID (optional)')
param appInsightsId string = ''

@description('Log Analytics Workspace resource ID (optional, used if appInsights not provided)')
param logAnalyticsId string = ''

@description('DNS Zone IDs for private endpoint registration')
param dnsZoneIds object

var hubName = 'aihub-${suffix}-${environment}'
var projectName = 'aiproj-${suffix}-${environment}'

// ---------------------------------------------------------------------------
// AI Foundry Hub (workspace kind: Hub)
// ---------------------------------------------------------------------------
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: hubName
  location: location
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'AI Foundry Hub - ${suffix} (${environment})'
    description: 'AI Foundry Hub with private networking - hub-spoke model'
    keyVault: keyVaultId
    storageAccount: storageAccountId
    containerRegistry: containerRegistryId
    applicationInsights: !empty(appInsightsId) ? appInsightsId : null
    publicNetworkAccess: 'Disabled'
    managedNetwork: {
      isolationMode: 'AllowInternetOutbound'
    }
  }
}

// ---------------------------------------------------------------------------
// AI Foundry Project (workspace kind: Project)
// ---------------------------------------------------------------------------
resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: projectName
  location: location
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'AI Foundry Project - ${suffix} (${environment})'
    description: 'AI Foundry Project - inherits networking from Hub'
    hubResourceId: aiHub.id
    publicNetworkAccess: 'Disabled'
  }
}

// ---------------------------------------------------------------------------
// Private Endpoint for AI Foundry Hub (Projects inherit from Hub)
// ---------------------------------------------------------------------------
resource hubPe 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: 'pe-aihub-${suffix}-${environment}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'pe-aihub-${suffix}-${environment}'
        properties: {
          privateLinkServiceId: aiHub.id
          groupIds: ['amlworkspace']
        }
      }
    ]
  }
}

resource hubPeDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: hubPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'aml'
        properties: { privateDnsZoneId: dnsZoneIds.aml }
      }
      {
        name: 'notebooks'
        properties: { privateDnsZoneId: dnsZoneIds.notebooks }
      }
    ]
  }
}

// NOTE: Projects inherit networking from the Hub — no separate PE needed

output hubId string = aiHub.id
output hubName string = aiHub.name
output hubPrincipalId string = aiHub.identity.principalId
output projectId string = aiProject.id
output projectName string = aiProject.name
output projectPrincipalId string = aiProject.identity.principalId
