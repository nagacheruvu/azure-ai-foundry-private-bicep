// ============================================================================
// Module: network.bicep
// VNet + Subnets for AI Foundry private deployment
// ============================================================================

@description('Azure region')
param location string

@description('Resource name suffix')
param suffix string

@description('VNet address space')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet for private endpoints')
param peSubnetPrefix string = '10.0.1.0/24'

@description('Subnet for AI Foundry compute (VNet injection)')
param computeSubnetPrefix string = '10.0.2.0/24'

@description('Subnet for ancillary services (Key Vault, Storage, etc.)')
param servicesSubnetPrefix string = '10.0.3.0/24'

var vnetName = 'vnet-aifoundry-${suffix}'
var peSubnetName = 'snet-pe'
var computeSubnetName = 'snet-compute'
var servicesSubnetName = 'snet-services'

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: peSubnetName
        properties: {
          addressPrefix: peSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: computeSubnetName
        properties: {
          addressPrefix: computeSubnetPrefix
          delegations: []
        }
      }
      {
        name: servicesSubnetName
        properties: {
          addressPrefix: servicesSubnetPrefix
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output peSubnetId string = vnet.properties.subnets[0].id
output computeSubnetId string = vnet.properties.subnets[1].id
output servicesSubnetId string = vnet.properties.subnets[2].id
