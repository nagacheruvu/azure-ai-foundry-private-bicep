// ============================================================================
// Module: azure-openai.bicep
// Azure OpenAI (Cognitive Services) with private endpoint
// ============================================================================

@description('Azure region')
param location string

@description('Resource name suffix')
param suffix string

@description('Environment label')
param environment string = 'dev'

@description('Subnet ID for private endpoints')
param peSubnetId string

@description('DNS Zone IDs for private endpoint registration')
param dnsZoneIds object

@description('Azure OpenAI SKU')
@allowed(['S0'])
param sku string = 'S0'

@description('Model deployments to create')
param modelDeployments array = [
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

var accountName = 'oai-${suffix}-${environment}'

// ---------------------------------------------------------------------------
// Azure OpenAI (Cognitive Services Account)
// ---------------------------------------------------------------------------
resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: accountName
  location: location
  kind: 'OpenAI'
  sku: { name: sku }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    disableLocalAuth: false
  }
}

// ---------------------------------------------------------------------------
// Model Deployments
// ---------------------------------------------------------------------------
@batchSize(1)
resource deployments 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [for deployment in modelDeployments: {
  parent: openAiAccount
  name: deployment.name
  sku: {
    name: 'Standard'
    capacity: deployment.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: deployment.model
      version: deployment.version
    }
  }
}]

// ---------------------------------------------------------------------------
// Private Endpoint
// ---------------------------------------------------------------------------
resource openAiPe 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: 'pe-oai-${suffix}-${environment}'
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'pe-oai-${suffix}-${environment}'
        properties: {
          privateLinkServiceId: openAiAccount.id
          groupIds: ['account']
        }
      }
    ]
  }
}

resource openAiPeDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: openAiPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'openai'
        properties: { privateDnsZoneId: dnsZoneIds.openai }
      }
      {
        name: 'cognitiveservices'
        properties: { privateDnsZoneId: dnsZoneIds.cognitiveServices }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output openAiAccountId string = openAiAccount.id
output openAiAccountName string = openAiAccount.name
output openAiEndpoint string = openAiAccount.properties.endpoint
output openAiPrincipalId string = openAiAccount.identity.principalId
