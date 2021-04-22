// ------------------------------------------------------------
// VNet - Build a vnet w/ subnets
//
//  Vnet Object
//
// Use this table for sub-object creation
//                        NSG    RouteTable  ServEndPt
//  GatewaySubnet                    X
//  AzureBastionSubnet     ?
//  AzureFirewallSubnet
//  <AllOthers>            X         X           X
// ------------------------------------------------------------

//Special vNet/Subnet objects
param vNetArray array
param subnetArray array

//Vnet build out
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
      }
    }]
  }
}]

//Special Subnets
var subnetRTOnly = [
  'GatewaySubnet'
]
var subnetNone = [
  'AzureBastionSubnet'
  'AzureFirewallSubnet'
]
var specialSubnet = [
  'GatewaySubnet'
  'AzureBastionSubnet'
  'AzureFirewallSubnet'
]

//Now create the other subnet information

//GatewaySubnet needs a Route Table
@batchSize(1)
module GWRouteTable 'modules/routetable.bicep' = [for (subnet, i) in subnetArray: if (contains(subnetRTOnly, subnet.subnetName)) {
  name: 'GWRouteTable-${subnet.vNetName}-${subnet.subnetName}-rt-${i}'
  scope: resourceGroup()
  params: {
    rtName: '${subnet.vNetName}-${subnet.subnetName}-rt'
    disableBGPProp: true
    routes: subnet.routes
  }
}]
module GWsubnet 'modules/subnet-rt.bicep' = [for (subnet, i) in subnetArray: if (contains(subnetRTOnly, subnet.subnetName)) {
  name: 'GWsubnet-${subnet.vNetName}-${subnet.subnetName}-${i}'
  params: {
    rgVnet: resourceGroup().name
    vNetName: subnet.vNetName
    subnetName: subnet.subnetName
    subnetAddressPrefix: subnet.SubnetAddressSpace
    serviceEndPoints: subnet.serviceEndPoints
  }
  dependsOn: [
    GWRouteTable
  ]
}]

//Bastion & Firewall - this assumes no NSG for bastion
@batchSize(1)
module BstFwSubnets 'modules/subnet-none.bicep' = [for (subnet, i) in subnetArray: if (contains(subnetNone, subnet.subnetName)) {
  name: 'BstFwSubnets-${subnet.vNetName}-${subnet.subnetName}-${i}'
  params: {
    rgVnet: resourceGroup().name
    vNetName: subnet.vNetName
    subnetName: subnet.subnetName
    subnetAddressPrefix: subnet.SubnetAddressSpace
    serviceEndPoints: subnet.serviceEndPoints
  }
  dependsOn: [
    GWsubnet
  ]
}]

//All others are both RT and NSG.  Note has to be serialized because of vNet update locks
module OtherRouteTable 'modules/routetable.bicep' = [for (subnet, i) in subnetArray: if (!contains(specialSubnet, subnet.subnetName)) {
  name: 'OtherRouteTable-${subnet.vNetName}-${subnet.subnetName}-rt-${i}'
  scope: resourceGroup()
  params: {
    rtName: '${subnet.vNetName}-${subnet.subnetName}-rt'
    disableBGPProp: true
    routes: subnet.routes
  }
}]
module OtherNSGTable 'modules/networksecuritygroup.bicep' = [for (subnet, i) in subnetArray: if (!contains(specialSubnet, subnet.subnetName)) {
  name: 'OtherNSGTable-${subnet.vNetName}-${subnet.subnetName}-nsg-${i}'
  scope: resourceGroup()
  params: {
    nsgName: '${subnet.vNetName}-${subnet.subnetName}-nsg'
    secRules: subnet.securityRules
  }
}]
@batchSize(1)
module OtherSubnets 'modules/subnet-both.bicep' = [for (subnet, i) in subnetArray: if (!contains(specialSubnet, subnet.subnetName)) {
  name: 'OtherSubnets-${subnet.vNetName}-${subnet.subnetName}-${i}'
  params: {
    rgVnet: resourceGroup().name
    vNetName: subnet.vNetName
    subnetName: subnet.subnetName
    subnetAddressPrefix: subnet.SubnetAddressSpace
    serviceEndPoints: subnet.serviceEndPoints
  }
  dependsOn: [
    BstFwSubnets
    OtherRouteTable
    OtherNSGTable
  ]
}]
