// ============================================================================
// Module: private-dns.bicep
// Private DNS Zones for AI Foundry ecosystem
// ============================================================================

@description('VNet resource ID to link')
param vnetId string

@description('VNet name for link naming')
param vnetName string

// All DNS zones needed for AI Foundry private deployment
var dnsZones = [
  'privatelink.api.azureml.ms'                    // AI Foundry Hub/Project
  'privatelink.notebooks.azure.net'               // Notebooks
  'privatelink.blob.${environment().suffixes.storage}'  // Storage blob
  'privatelink.file.${environment().suffixes.storage}'  // Storage file
  'privatelink.vaultcore.azure.net'               // Key Vault
  'privatelink.azurecr.io'                        // Container Registry
  'privatelink.openai.azure.com'                  // Azure OpenAI
  'privatelink.cognitiveservices.azure.com'       // Cognitive Services
  'privatelink.search.windows.net'                // AI Search
]

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in dnsZones: {
  name: zone
  location: 'global'
}]

resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in dnsZones: {
  parent: privateDnsZones[i]
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnetId }
    registrationEnabled: false
  }
}]

output dnsZoneIds object = {
  aml: privateDnsZones[0].id
  notebooks: privateDnsZones[1].id
  blob: privateDnsZones[2].id
  file: privateDnsZones[3].id
  keyVault: privateDnsZones[4].id
  acr: privateDnsZones[5].id
  openai: privateDnsZones[6].id
  cognitiveServices: privateDnsZones[7].id
  search: privateDnsZones[8].id
}
