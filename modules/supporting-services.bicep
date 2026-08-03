// ============================================================================
// Module: supporting-services.bicep
// Key Vault, Storage, ACR, App Insights — conditionally created with PEs
// ============================================================================

@description('Azure region')
param location string

@description('Resource name suffix (must be globally unique for storage)')
param suffix string

@description('Subnet ID for private endpoints')
param peSubnetId string

@description('DNS Zone IDs for private endpoint registration')
param dnsZoneIds object

@description('Create new Key Vault')
param createKeyVault bool = true

@description('Create new Storage Account')
param createStorage bool = true

@description('Create new Container Registry')
param createAcr bool = true

@description('Create new Log Analytics + App Insights')
param createLogAnalytics bool = true

// ---------------------------------------------------------------------------
// Key Vault
// ---------------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = if (createKeyVault) {
  name: 'kv-aif-${suffix}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource kvPe 'Microsoft.Network/privateEndpoints@2024-01-01' = if (createKeyVault) {
  name: 'pe-kv-${suffix}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'pe-kv-${suffix}'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
}

resource kvPeDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = if (createKeyVault) {
  parent: kvPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'keyvault', properties: { privateDnsZoneId: dnsZoneIds.keyVault } }
    ]
  }
}

// ---------------------------------------------------------------------------
// Storage Account
// ---------------------------------------------------------------------------
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = if (createStorage) {
  name: 'staif${suffix}'
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource stBlobPe 'Microsoft.Network/privateEndpoints@2024-01-01' = if (createStorage) {
  name: 'pe-st-blob-${suffix}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'pe-st-blob-${suffix}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
}

resource stBlobPeDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = if (createStorage) {
  parent: stBlobPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'blob', properties: { privateDnsZoneId: dnsZoneIds.blob } }
    ]
  }
}

resource stFilePe 'Microsoft.Network/privateEndpoints@2024-01-01' = if (createStorage) {
  name: 'pe-st-file-${suffix}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'pe-st-file-${suffix}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['file']
        }
      }
    ]
  }
}

resource stFilePeDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = if (createStorage) {
  parent: stFilePe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'file', properties: { privateDnsZoneId: dnsZoneIds.file } }
    ]
  }
}

// ---------------------------------------------------------------------------
// Container Registry
// ---------------------------------------------------------------------------
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = if (createAcr) {
  name: 'craif${suffix}'
  location: location
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

resource acrPe 'Microsoft.Network/privateEndpoints@2024-01-01' = if (createAcr) {
  name: 'pe-acr-${suffix}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'pe-acr-${suffix}'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: ['registry']
        }
      }
    ]
  }
}

resource acrPeDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = if (createAcr) {
  parent: acrPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'acr', properties: { privateDnsZoneId: dnsZoneIds.acr } }
    ]
  }
}

// ---------------------------------------------------------------------------
// Application Insights + Log Analytics
// ---------------------------------------------------------------------------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (createLogAnalytics) {
  name: 'law-aif-${suffix}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (createLogAnalytics) {
  name: 'appi-aif-${suffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output keyVaultId string = createKeyVault ? keyVault.id : ''
output storageAccountId string = createStorage ? storageAccount.id : ''
output containerRegistryId string = createAcr ? acr.id : ''
output appInsightsId string = createLogAnalytics ? appInsights.id : ''
output keyVaultName string = createKeyVault ? keyVault.name : ''
output storageAccountName string = createStorage ? storageAccount.name : ''
output acrName string = createAcr ? acr.name : ''
