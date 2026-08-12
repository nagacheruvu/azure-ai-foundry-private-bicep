// ============================================================================
// Module: naming.bicep
// CAF naming convention defaults with override capability
// Reference: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
// ============================================================================

@description('Workload or project name (e.g., "contoso", "kf")')
param workloadName string

@description('Environment short name')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Azure region short name (e.g., "eus2" for eastus2)')
param regionShortName string = 'eus2'

@description('Optional instance number for uniqueness')
param instance string = '001'

// ---------------------------------------------------------------------------
// CAF naming pattern: {resource-abbreviation}-{workload}-{environment}-{region}-{instance}
// Override any name by passing the override parameter directly
// ---------------------------------------------------------------------------

// AI Foundry Hub: hub-{workload}-{env}-{region}-{instance}
@description('Override: AI Foundry Hub name')
param hubNameOverride string = ''
var hubNameDefault = 'hub-${workloadName}-${environment}-${regionShortName}-${instance}'
output hubName string = !empty(hubNameOverride) ? hubNameOverride : hubNameDefault

// AI Foundry Project: proj-{workload}-{env}-{region}-{instance}
@description('Override: AI Foundry Project name')
param projectNameOverride string = ''
var projectNameDefault = 'proj-${workloadName}-${environment}-${regionShortName}-${instance}'
output projectName string = !empty(projectNameOverride) ? projectNameOverride : projectNameDefault

// Azure OpenAI: oai-{workload}-{env}-{region}-{instance}
@description('Override: Azure OpenAI name')
param openAiNameOverride string = ''
var openAiNameDefault = 'oai-${workloadName}-${environment}-${regionShortName}-${instance}'
output openAiName string = !empty(openAiNameOverride) ? openAiNameOverride : openAiNameDefault

// Key Vault: kv-{workload}-{env}-{region}-{instance} (max 24 chars)
@description('Override: Key Vault name')
param keyVaultNameOverride string = ''
var kvRaw = 'kv-${workloadName}-${environment}-${regionShortName}-${instance}'
var keyVaultNameDefault = length(kvRaw) > 24 ? substring(kvRaw, 0, 24) : kvRaw
output keyVaultName string = !empty(keyVaultNameOverride) ? keyVaultNameOverride : keyVaultNameDefault

// Storage Account: st{workload}{env}{region}{instance} (max 24 chars, alphanumeric only)
@description('Override: Storage Account name')
param storageNameOverride string = ''
var stRaw = 'st${workloadName}${environment}${regionShortName}${instance}'
var storageNameDefault = length(stRaw) > 24 ? substring(stRaw, 0, 24) : stRaw
output storageName string = !empty(storageNameOverride) ? storageNameOverride : storageNameDefault

// Container Registry: cr{workload}{env}{region}{instance} (max 50 chars, alphanumeric only)
@description('Override: Container Registry name')
param acrNameOverride string = ''
var crRaw = 'cr${workloadName}${environment}${regionShortName}${instance}'
output acrName string = !empty(acrNameOverride) ? acrNameOverride : crRaw

// Log Analytics: log-{workload}-{env}-{region}-{instance}
@description('Override: Log Analytics Workspace name')
param logAnalyticsNameOverride string = ''
var logNameDefault = 'log-${workloadName}-${environment}-${regionShortName}-${instance}'
output logAnalyticsName string = !empty(logAnalyticsNameOverride) ? logAnalyticsNameOverride : logNameDefault

// Application Insights: appi-{workload}-{env}-{region}-{instance}
@description('Override: Application Insights name')
param appInsightsNameOverride string = ''
var appiNameDefault = 'appi-${workloadName}-${environment}-${regionShortName}-${instance}'
output appInsightsName string = !empty(appInsightsNameOverride) ? appInsightsNameOverride : appiNameDefault

// VNet: vnet-{workload}-{env}-{region}-{instance}
@description('Override: VNet name')
param vnetNameOverride string = ''
var vnetNameDefault = 'vnet-${workloadName}-${environment}-${regionShortName}-${instance}'
output vnetName string = !empty(vnetNameOverride) ? vnetNameOverride : vnetNameDefault

// Private Endpoint prefix: pep-{service}-{workload}-{env}
output pepPrefix string = 'pep-'
output pepSuffix string = '-${workloadName}-${environment}-${regionShortName}-${instance}'
