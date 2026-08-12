// ============================================================================
// Module: supporting-services.bicep
// Key Vault, Storage, ACR, App Insights — using Azure Verified Modules (AVM)
// CAF naming convention with override capability
// ============================================================================

@description('Azure region')
param location string

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
// CAF resource names (passed from naming module or overridden)
// ---------------------------------------------------------------------------
@description('Key Vault name (CAF: kv-{workload}-{env}-{region}-{instance})')
param keyVaultName string

@description('Storage Account name (CAF: st{workload}{env}{region}{instance})')
param storageName string

@description('Container Registry name (CAF: cr{workload}{env}{region}{instance})')
param acrName string

@description('Log Analytics Workspace name (CAF: log-{workload}-{env}-{region}-{instance})')
param logAnalyticsName string

@description('Application Insights name (CAF: appi-{workload}-{env}-{region}-{instance})')
param appInsightsName string

@description('Private Endpoint name suffix (CAF: pep-{service}-{suffix})')
param pepSuffix string

// ---------------------------------------------------------------------------
// Key Vault (AVM)
// ---------------------------------------------------------------------------
module keyVault 'br/public:avm/res/key-vault/vault:0.14.0' = if (createKeyVault) {
  name: 'deploy-kv'
  params: {
    name: keyVaultName
    location: location
    enableRbacAuthorization: true
    enableSoftDelete: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    privateEndpoints: [
      {
        name: 'pep-kv${pepSuffix}'
        subnetResourceId: peSubnetId
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            { privateDnsZoneResourceId: dnsZoneIds.keyVault }
          ]
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Storage Account (AVM)
// ---------------------------------------------------------------------------
module storageAccount 'br/public:avm/res/storage/storage-account:0.33.0' = if (createStorage) {
  name: 'deploy-st'
  params: {
    name: storageName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    minimumTlsVersion: 'TLS1_2'
    privateEndpoints: [
      {
        name: 'pep-st-blob${pepSuffix}'
        subnetResourceId: peSubnetId
        service: 'blob'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            { privateDnsZoneResourceId: dnsZoneIds.blob }
          ]
        }
      }
      {
        name: 'pep-st-file${pepSuffix}'
        subnetResourceId: peSubnetId
        service: 'file'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            { privateDnsZoneResourceId: dnsZoneIds.file }
          ]
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Container Registry (AVM)
// ---------------------------------------------------------------------------
module acr 'br/public:avm/res/container-registry/registry:0.12.1' = if (createAcr) {
  name: 'deploy-cr'
  params: {
    name: acrName
    location: location
    acrSku: 'Premium'
    acrAdminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    privateEndpoints: [
      {
        name: 'pep-cr${pepSuffix}'
        subnetResourceId: peSubnetId
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            { privateDnsZoneResourceId: dnsZoneIds.acr }
          ]
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Log Analytics + Application Insights (AVM)
// ---------------------------------------------------------------------------
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.16.1' = if (createLogAnalytics) {
  name: 'deploy-log'
  params: {
    name: logAnalyticsName
    location: location
    skuName: 'PerGB2018'
    dataRetention: 30
  }
}

module appInsights 'br/public:avm/res/insights/component:0.8.0' = if (createLogAnalytics) {
  name: 'deploy-appi'
  params: {
    name: appInsightsName
    location: location
    kind: 'web'
    applicationType: 'web'
    workspaceResourceId: logAnalytics.outputs.resourceId
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output keyVaultId string = createKeyVault ? keyVault.outputs.resourceId : ''
output storageAccountId string = createStorage ? storageAccount.outputs.resourceId : ''
output containerRegistryId string = createAcr ? acr.outputs.resourceId : ''
output appInsightsId string = createLogAnalytics ? appInsights.outputs.resourceId : ''
output keyVaultNameOut string = createKeyVault ? keyVault.outputs.name : ''
output storageAccountNameOut string = createStorage ? storageAccount.outputs.name : ''
output acrNameOut string = createAcr ? acr.outputs.name : ''
