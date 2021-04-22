// ------------------------------------------------------------
// networkSecurityGroups -
//  The securityRules object is an array of rules
//   [
//     {
//       name: 'default-allow-rdp'
//       properties: {
//         priority: 1010
//         access: 'Allow'
//         direction: 'Inbound'
//         protocol: 'Tcp'
//         sourcePortRange: '*'
//         sourceAddressPrefix: 'VirtualNetwork'
//         destinationAddressPrefix: '*'
//         destinationPortRange: '3389'
//       }
//     }
//   ]
// ------------------------------------------------------------
param nsgName string
param secRules array

resource nsg  'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: nsgName
  location: resourceGroup().location
  properties: {
    securityRules: secRules
  }
}

output id string = nsg.id
