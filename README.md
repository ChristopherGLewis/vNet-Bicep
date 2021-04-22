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


## Bicep Notes
There are some tricks that are used in the bicep files to work with this.

### Subnet Modules

There are four subnet modules based off of the NSG/RT requirements.  This is required
because the route/NSG fields will not take a null or '' for the resource id.

``` JSON
routeTable: {
      id: ''       <-- Causes errors
}

-or-

routeTable:  null() <-- Causes errors
```

This requires four subnet modules (subnet-rt, subnet-nsg, subnet-both and subnet-none).

## RouteTable and NetworkSecurityGroup modules
There are also modules for the RT's and NSG's that can be used to create blank
tables or full tables if the appropriate arrays of objects are passed to them.

The details of the object requirements are documented in each file, and are driven
by the object formats here:

* https://docs.microsoft.com/en-us/azure/templates/microsoft.network/networksecuritygroups/securityrules?tabs=json#securityrulepropertiesformat-object

* https://docs.microsoft.com/en-us/azure/templates/microsoft.network/routetables/routes?tabs=json#routepropertiesformat-object

## Loops
The main vNet.Bicep file runs a series of loops to build out each type of object.

The vNet loop is pretty simple with name and address.  There is a section that minimally
defines the subnets for the vnet with address space only.  This prevents the subnets from
being dropped on re-deployments, but will remove all route tables and NSG tables from
the subnets.

The secondary rt/nsg/subnet loops use conditionals to determine what type of subnet
to deploy for the special subnets.  Because ARM evaluates loops before conditionals,
each of these loops runs through the entire subnetArray and only gets processed for
the special subnets that require the particular configuration. You should note that the
names of the loops are fully qualified ("loop-vnet-subnet-index") to ensure uniqueness at the
resource name level.

All in all this process would be *much* simpler if ARM allowed a null reference for
a routetable or NSG ID.
