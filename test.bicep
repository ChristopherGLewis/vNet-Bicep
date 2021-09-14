param nicName string
param location string
param staticIP string
param subnetid string

param nsgid string = ''
var nsgValue = nsgid != '' ? {
  id: nsgid
} : {}

resource nInter 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: nicName
  location: location

  properties: {
  ipConfigurations: [
      {
         name: 'ipconfig1'
         properties: {
           privateIPAllocationMethod: staticIP != 'blank' ? 'Static' : 'Dynamic'
           privateIPAddress: staticIP != 'blank' ? staticIP : null
           subnet: {
             id: subnetid
           }
         }
      }
    ]
    networkSecurityGroup: nsgValue
  }
}
