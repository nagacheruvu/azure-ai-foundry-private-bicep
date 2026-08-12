// ============================================================================
// Module: azure-openai.bicep
// Azure OpenAI using Azure Verified Module (AVM)
// CAF naming: oai-{workload}-{env}-{region}-{instance}
// ============================================================================

@description('Azure region')
param location string

@description('Subnet ID for private endpoints')
param peSubnetId string

@description('DNS Zone IDs for private endpoint registration')
param dnsZoneIds object

@description('Azure OpenAI name (CAF: oai-{workload}-{env}-{region}-{instance})')
param openAiName string

@description('Private Endpoint name suffix')
param pepSuffix string

@description('Azure OpenAI SKU')
@allowed(['S0'])
param sku string = 'S0'

@description('Model deployments to create')
param modelDeployments array = [
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

// ---------------------------------------------------------------------------
// Azure OpenAI (AVM: cognitive-services/account)
// ---------------------------------------------------------------------------
module openAiAccount 'br/public:avm/res/cognitive-services/account:0.18.0' = {
  name: 'deploy-oai'
  params: {
    name: openAiName
    location: location
    kind: 'OpenAI'
    sku: sku
    managedIdentities: { systemAssigned: true }
    customSubDomainName: openAiName
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
    }
    deployments: [for deployment in modelDeployments: {
      name: deployment.name
      model: {
        format: 'OpenAI'
        name: deployment.model
        version: deployment.version
      }
      sku: {
        name: 'Standard'
        capacity: deployment.capacity
      }
    }]
    privateEndpoints: [
      {
        name: 'pep-oai${pepSuffix}'
        subnetResourceId: peSubnetId
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            { privateDnsZoneResourceId: dnsZoneIds.openai }
            { privateDnsZoneResourceId: dnsZoneIds.cognitiveServices }
          ]
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output openAiAccountId string = openAiAccount.outputs.resourceId
output openAiAccountName string = openAiAccount.outputs.name
output openAiEndpoint string = openAiAccount.outputs.endpoint
output openAiPrincipalId string = openAiAccount.outputs.systemAssignedMIPrincipalId
