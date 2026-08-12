// ============================================================================
// Module: ai-foundry.bicep
// AI Foundry Hub + Project using Azure Verified Modules (AVM)
// CAF naming: hub-{workload}, proj-{workload}
// ============================================================================

@description('Azure region')
param location string

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

@description('Log Analytics Workspace resource ID (optional)')
param logAnalyticsId string = ''

@description('DNS Zone IDs for private endpoint registration')
param dnsZoneIds object

@description('Managed network isolation mode')
@allowed(['AllowInternetOutbound', 'AllowOnlyApprovedOutbound'])
param managedNetworkIsolationMode string = 'AllowOnlyApprovedOutbound'

@description('Azure OpenAI account resource ID (for managed network outbound PE rule)')
param openAiAccountId string = ''

// ---------------------------------------------------------------------------
// CAF resource names (passed from naming module or overridden)
// ---------------------------------------------------------------------------
@description('AI Foundry Hub name (CAF: hub-{workload}-{env}-{region}-{instance})')
param hubName string

@description('AI Foundry Project name (CAF: proj-{workload}-{env}-{region}-{instance})')
param projectName string

@description('Private Endpoint name suffix')
param pepSuffix string

// Outbound rules for managed network (OpenAI PE if provided)
var outboundRulesWithOpenAi = {
  'openai-pe': {
    type: 'PrivateEndpoint'
    destination: {
      serviceResourceId: openAiAccountId
      subresourceTarget: 'account'
      sparkEnabled: false
    }
    category: 'UserDefined'
  }
}

// ---------------------------------------------------------------------------
// AI Foundry Hub (AVM: machine-learning-services/workspace, kind: Hub)
// ---------------------------------------------------------------------------
module aiHub 'br/public:avm/res/machine-learning-services/workspace:0.14.0' = {
  name: 'deploy-hub'
  params: {
    name: hubName
    location: location
    sku: 'Basic'
    kind: 'Hub'
    managedIdentities: { systemAssigned: true }
    associatedKeyVaultResourceId: keyVaultId
    associatedStorageAccountResourceId: storageAccountId
    associatedContainerRegistryResourceId: containerRegistryId
    associatedApplicationInsightsResourceId: !empty(appInsightsId) ? appInsightsId : null
    description: 'AI Foundry Hub with private networking'
    publicNetworkAccess: 'Disabled'
    managedNetworkSettings: {
      isolationMode: managedNetworkIsolationMode
      outboundRules: !empty(openAiAccountId) ? outboundRulesWithOpenAi : {}
    }
    privateEndpoints: [
      {
        name: 'pep-hub${pepSuffix}'
        subnetResourceId: peSubnetId
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            { privateDnsZoneResourceId: dnsZoneIds.aml }
            { privateDnsZoneResourceId: dnsZoneIds.notebooks }
          ]
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// AI Foundry Project (AVM: machine-learning-services/workspace, kind: Project)
// ---------------------------------------------------------------------------
module aiProject 'br/public:avm/res/machine-learning-services/workspace:0.14.0' = {
  name: 'deploy-proj'
  params: {
    name: projectName
    location: location
    sku: 'Basic'
    kind: 'Project'
    managedIdentities: { systemAssigned: true }
    hubResourceId: aiHub.outputs.resourceId
    description: 'AI Foundry Project - inherits networking from Hub'
    publicNetworkAccess: 'Disabled'
  }
}

// NOTE: Projects inherit networking from the Hub — no separate PE needed

output hubId string = aiHub.outputs.resourceId
output hubName string = aiHub.outputs.name
output hubPrincipalId string = aiHub.outputs.systemAssignedMIPrincipalId
output projectId string = aiProject.outputs.resourceId
output projectName string = aiProject.outputs.name
output projectPrincipalId string = aiProject.outputs.systemAssignedMIPrincipalId
