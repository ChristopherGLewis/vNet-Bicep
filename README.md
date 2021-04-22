# Virtual Network Bicep deployment

The vnet deployment used to fully deploy a network in one pass.  Currently this is problematic
due to the complexities of the NSG/RT requirements of the special networks.

# Script
The script to deploy a network is `Deploy-Network.ps1`. This is a resource group
based deployment and deploys all vnets within a single RG.  This script reads a vnetParam.json
file that has a definition of the vnets as a JSON file

``` PowerShell

.\Deploy-Network.ps1 -ValidateOnly
.\Deploy-Network.ps1 -SaveParameterFile  #Does not delete the Temp PARAM file

```
# vNet Parameters

The ARM template takes two complex parameters

## VNetArray

The vNet array is a JSON array of a flat vNet object - note that extra fields are ignored

``` JSON
[
  {
    "vNetName": "vnet00",
    "vNetRG": "rgNetworking",
    "vNetLocation": "centralUs",
    "NetworkType": "Hub",
    "vNetAddressSpace": "10.200.0.0/24",
    "subnetArray": "..."
  },
  {
    "vNetName": "vnet01",
    "vNetLocation": "centralUs",
    "NetworkType": "Spoke",
    "vNetAddressSpace": "10.200.1.0/24",
    "subnetArray": "..."
  }
]
```

## SubnetArray

The subnetArray is *all* the subnets for all vnets.  Note that the serviceEndpoints,
securityRules and routes are arrays of the actual required ARM objects

``` JSON
[
  {
    "vNetName": "vnet00",
    "subnetName": "GatewaySubnet",
    "SubnetAddressSpace": "10.200.0.0/27",
    "serviceEndpoints": [],
    "securityRules": [],
    "routes": []
  },
  {
    "vNetName": "vnet00",
    "subnetName": "AzureBastionSubnet",
    "SubnetAddressSpace": "10.200.0.32/27",
    "serviceEndpoints": [],
    "securityRules": [],
    "routes": []
  },
. . .
  {
    "vNetName": "vnet01",
    "subnetName": "adtier",
    "SubnetAddressSpace": "10.200.1.192/26",
    "serviceEndpoints": [],
    "securityRules": [],
    "routes": []
  }
]
```

These objects are generated from the vnetParam.json file.

### Routes

The routes object is an array of route table entries

``` JSON
    [
      {
        "name": "DefaultRoute",
        "properties": {
          "addressPrefix" : "0.0.0.0/0'",
          "nextHopType" : "VirtualAppliance",
          "nextHopIpAddress" : "10.0.0.1"
        }
      }
    ]
```

### networkSecurityGroups

The securityRules object is an array of rules

``` JSON
  [
    {
      "name" : "default-allow-rdp",
      "properties" : {
        "priority": 1010,
        "access": "Allow",
        "direction": "Inbound",
        "protocol": "Tcp",
        "sourcePortRange": "*",
        "sourceAddressPrefix": "VirtualNetwork",
        "destinationAddressPrefix": "*",
        "destinationPortRange": "3389"
      }
    }
  ]
```

### ServiceEndPoints

The serviceEndPoints object is an array of service

``` JSON
  [
    {
      "locations": [
        "centralus",
        "eastus2"
      ],
      "service": "Microsoft.Sql"
    },
    {
      "locations": [
        "centralus",
        "eastus2"
      ],
      "service": "Microsoft.Storage"
    },
    {
      "locations": [
        "centralus",
        "eastus2"
      ],
      "service": "Microsoft.KeyVault"
    }
  ]
```

## NOTES

Even though this is an incremental deployment, it is a **disruptive** deployment of a
vNet in Azure.

This deployment keeps the subnets but drops the RouteTable, NSG and Service Endpoints
 and re-add them.  It will also drop any subnet delegations sine this code doesn't
support that at this time.

Another thing to note is that this does allow for resizing of the base vNet and
subnets.  The base vnet can grow and shrink as long as none of the subnets are
out of the new range.  Subnets can be resized within the vNet, but can't cause
overlaps and cannot be resized if they have any resources attached to them (NICs,
PaaS Services etc).  This fundamentally restricts the usability of *any* vNet code
for CI/CD IaC processes if the code touches the subnets.

See this link: https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deployment-modes#incremental-mode for further details.
