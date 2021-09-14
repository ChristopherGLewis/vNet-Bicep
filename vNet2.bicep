// ------------------------------------------------------------
// VNet - Build a vnet w/ subnets
//
// Use this table for sub-object creation
//                        NSG    RouteTable  ServEndPt
//  GatewaySubnet                    X
//  AzureBastionSubnet     ?
//  AzureFirewallSubnet              X
//  <AllOthers>            X         X           X
// ------------------------------------------------------------

//Special vNet/Subnet objects
param vNetArray array
param subnetArray array

param tags object = {
  'Environment': 'prop'
  'Location': 'usce'
  'application': 'Network'
  'ALL_CAPS': 'ALL_CAPS'
  'all_lower': 'all_lower'
  'Mixed_Case' : 'Mixed_Case'
}

//Special Subnets
var subnetRTOnly = [
  'GatewaySubnet'
  'AzureFirewallSubnet'
]
var subnetNone = [
  'AzureBastionSubnet' //Bastion can have an NSG.  This code doesn't support it
]
var subnetNSGOnly = [
  //  'AzureBastionSubnet'
]

//This is an array of all the above so we can separate special subnets
//from "normal" subnets
var specialSubnet = [
  'GatewaySubnet'
  'AzureBastionSubnet'
  'AzureFirewallSubnet'
]

//Create route tables for subnets that require them
@batchSize(1)
module RouteTable 'modules/routetable.bicep' = [for (subnet, i) in subnetArray: if (contains(subnetRTOnly, subnet.subnetName) || !contains(specialSubnet, subnet.subnetName)) {
  name: 'RouteTable-${subnet.vNetName}-${subnet.subnetName}-rt-${i}'
  scope: resourceGroup()
  params: {
    rtName: '${subnet.vNetName}-${subnet.subnetName}-rt'
    disableBGPProp: true
    routes: subnet.routes
    tags: tags
  }
}]
//Create NSG tables for subnets that require them
module NSGTable 'modules/networksecuritygroup.bicep' = [for (subnet, i) in subnetArray: if (contains(subnetNSGOnly, subnet.subnetName) || !contains(specialSubnet, subnet.subnetName)) {
  name: 'NSGTable-${subnet.vNetName}-${subnet.subnetName}-nsg-${i}'
  scope: resourceGroup()
  params: {
    nsgName: '${subnet.vNetName}-${subnet.subnetName}-nsg'
    secRules: subnet.securityRules
    tags: tags
  }
}]

//Vnet build out
@batchSize(1)
resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = [for (vnet, i) in vNetArray: {
  name: '${vnet.vnetName}'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet.vNetAddressSpace
      ]
    }
    enableDdosProtection: false
    //This is a minimal subnet loop - this keeps the subnets from dropping
    //but temporarily removes the RT/NSG/ServiceEndpoints
    //Note it will probably break subnet delegation
    subnets: [for subnet in vnet.subnets: {
      name: subnet.SubnetName
      properties: {
        addressPrefix: subnet.SubnetAddressSpace
        serviceEndpoints: subnet.serviceEndPoints
        networkSecurityGroup: (contains(subnetNSGOnly, subnet.subnetName) || !contains(specialSubnet, subnet.subnetName)) ? {
          id: resourceId('Microsoft.Networking/networkSecurityGroups', '${vnet.vnetName}-${subnet.SubnetName}-nsg')
        } : json('null')
        routeTable: (contains(subnetRTOnly, subnet.subnetName) || !contains(specialSubnet, subnet.subnetName)) ? {
          id: resourceId('Microsoft.Networking/routeTables', '${vnet.vnetName}-${subnet.SubnetName}-rt')
        } : json('null')
      }
    }]

  }
  dependsOn: [
    RouteTable
    NSGTable
  ]
  tags: union(tags, {
    'NetworkType' : vnet.NetworkType
  } )
}]
