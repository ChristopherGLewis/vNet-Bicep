// ------------------------------------------------------------
// Subnet with NSG only
// serviceEndPoints
//  The serviceEndPoints object is an array of service
//    [
//        {
//            "locations": [
//                "centralus",
//                "eastus2"
//            ],
//            "service": "Microsoft.Sql"
//        },
//        {
//            "locations": [
//                "centralus",
//                "eastus2"
//            ],
//            "service": "Microsoft.Storage"
//        },
//        {
//            "locations": [
//                "centralus",
//                "eastus2"
//            ],
//            "service": "Microsoft.KeyVault"
//        }
//    ]
// ------------------------------------------------------------

param vNetName string
param rgVnet string
param subnetName string
param subnetAddressPrefix string
param serviceEndPoints array = []

//Subnet with RT and NSG
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = {
  name: '${vNetName}/${subnetName}'
  properties: {
    addressPrefix: subnetAddressPrefix
    serviceEndpoints: serviceEndPoints
    networkSecurityGroup: {
      id: resourceId('Microsoft.Networking/networkSecurityGroups', '${vNetName}-${subnetName}-nsg')
    }
  }
}
