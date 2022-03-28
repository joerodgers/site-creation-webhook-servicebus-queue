param
(
    [parameter(Mandatory=$false)]
    [string]
    $InputPath = "$PSScriptRoot\resources\azure-deploy.json",

    [parameter(Mandatory=$false)]
    [ValidateSet("Production", "Test", "Development")]
    [string]
    $Environment = "Development",

    [parameter(Mandatory=$false)]
    [switch]
    $Force
)

Import-Module -Name "$PSScriptRoot\resources\resources.psm1" -Force -ErrorAction Stop

if( -not (Test-Path -Path $InputPath -PathType Leaf) )
{
    Write-Error "Template file not found at $InputPath."
    return
}

$path = Get-ArmTemplateParameterFilePath -Environment $Environment

if( -not $Force.IsPresent -and (Test-Path -Path $path -PathType Leaf) )
{
    Write-Error "Parameter file exists at $path. To overwrite the existing parameter file include the -Force option."
    return
}

New-ArmTemplateParameterFile -InputPath  $InputPath -Environment $Environment



