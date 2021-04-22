// ------------------------------------------------------------
// RouteTable
//  The routes object is an array of route table entries
//    [
//      {
//        name: 'DefaultRoute'
//        properties: {
//          addressPrefix: '0.0.0.0/0'
//          nextHopType: 'VirtualAppliance'
//          nextHopIpAddress: 10.0.0.1
//        }
//      }
//    ]
// See
//  https://docs.microsoft.com/en-us/azure/templates/microsoft.network/routetables/routes?tabs=json#routepropertiesformat-object
// for more information
// ------------------------------------------------------------

param rtName string
param disableBGPProp bool = false
param routes array = []  //empty

//param azFwlIp string

resource routetable 'Microsoft.Network/routeTables@2020-06-01' = {
  name: rtName
  location: resourceGroup().location
  properties: {
    disableBgpRoutePropagation: disableBGPProp
    routes: routes
  }
}

output id string = routetable.id
