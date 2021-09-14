#Requires -Version 3.0
[CmdletBinding()]
Param(
  [Parameter(Mandatory = $false)]
  [string] $ARMTemplate = 'vNet.json',

  [Parameter(Mandatory = $false)]
  [switch] $ValidateOnly,

  [Parameter(Mandatory = $false)]
  [switch] $SaveParameterFile
)

Function Convert-ParamHashToARMParamJson {
  param (
    [hashtable] $Hash
  )

  $obj = [ordered]@{
    '$Schema'         = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    '$contentVersion' = "1.0.0.0"
    'parameters'      = @{}
  }
  foreach ($Key in $($Hash.Keys) ) {
    #Currently only handles string, int, bool & PSCustomObject values
    switch ($Hash.Item($key).GetType().Name) {
      'string' { $obj.parameters.Add($Key, @{"value" = [string] $Hash.Item($Key) }) }
      'bool' { $obj.parameters.Add($Key, @{"value" = [bool] $Hash.Item($Key) }) }
      'int' { $obj.parameters.Add($Key, @{"value" = [int] $Hash.Item($Key) }) }
      'PSCustomObject' { $obj.parameters.Add($Key, $Hash.Item($Key) ) }
      'array' {
        Write-Host "ARRAY!!!"  -ForegroundColor Red
      }
      default { $obj.parameters.Add($Key, @{"value" = $Hash.Item($Key) }) }
    }
  }
  return $obj | ConvertTo-Json -depth 99
}

$ScriptName = $MyInvocation.MyCommand.Name
$ScriptStartTime = Get-Date
Write-Host "Running '$ScriptName' Script starting at $($ScriptStartTime.ToString("yyyy-MM-dd HH:mm:ss zzz"))" -ForegroundColor Green

$RGName = 'BicepTesting'
$AzRegion = 'Central US'
$vnetParamFile = Join-Path -Path $PSScriptRoot -ChildPath "vnetParam.json"

Write-Host "  Loading vnetParam.json '$vnetParamFile'" -ForegroundColor Green
$vnetObject = Get-Content $vnetParamFile |  ConvertFrom-Json

$vnetArray = $vnetObject.vNetArray
# we have to get all subnets in a separate array since Bicep/ARM has minimal array filtering
# This would be eliminated with a where clause.  Not sure if INTERSECTION would work???
$subnetArray = $vnetArray.subnets

#Parameter hash - note that New-AzResourceGroupDeployment doesn't seem to support
#hash tables with complex objects, so write this to a temp ARMTemplate Parameter File
if ( $ARMTemplate.contains('vnet2', [System.StringComparison]::CurrentCultureIgnoreCase ) ) {
  $Tags = @{
    'Environment' = 'prop'
    'Location'    = 'usce'
    'application' = 'Network'
    'ALL_CAPS'    = 'ALL_CAPS'
    'all_lower'   = 'all_lower'
    'Mixed_Case'  = 'Mixed_Case'
  }
  $Parameters = @{
    vNetArray   = $vNetArray
    subnetArray = $subnetArray
    tags        = $tags
  }
} else {
  $Parameters = @{
    vNetArray   = $vNetArray
    subnetArray = $subnetArray
  }
}

#Dump Parameters
Write-Host "-- Parameters --" -ForegroundColor Green
$Parameters
Write-Host "----------------" -ForegroundColor Green

#create a temp file
$tempFile = New-TemporaryFile
#Make our object/json
$ARMParam = Convert-ParamHashToARMParamJson -hash $Parameters
Write-Host "  Temp parameters file: '$($tempFile)'" -ForegroundColor Green
$ARMParam | Set-Content -Path $tempFile

$vnetARM = Join-Path -Path $PSScriptRoot -ChildPath $ARMTemplate

if ($ValidateOnly) {
  Test-AzResourceGroupDeployment  -ResourceGroupName $RGName  -TemplateFile $vnetARM -TemplateParameterFile $tempFile -Verbose
} else {
  $DeployName = "Deploy_vNet_" + (Get-Date).ToString("yyyyMMdd-HHmmss")
  New-AzResourceGroupDeployment -Name $DeployName -ResourceGroupName $RGName  -TemplateFile $vnetARM -TemplateParameterFile $tempFile -Verbose
}

if (-not $SaveParameterFile) {
  Write-Host "  Removing temp parameters file: '$($tempFile)'" -ForegroundColor Green
  $tempFile.Delete()
}

$Duration = (Get-Date) - $ScriptStartTime
$DurString = $Duration.ToString("hh\:mm\:ss")
Write-Host "Completed '$ScriptName' in $DurString at $(get-date -Format "yyyy-MM-dd HH:mm:ss zzz")`n" -ForegroundColor Green
