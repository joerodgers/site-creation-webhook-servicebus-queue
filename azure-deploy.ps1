#requires -modules "Az.Resources", "Az.Accounts", "Az.Websites"

param
(
    [parameter(Mandatory=$false)]
    [ValidateSet("Production", "Test", "Development")]
    [string]
    $Environment = "Development",

    [parameter(Mandatory=$true)]
    [Guid]
    $TenantId,

    [parameter(Mandatory=$true)]
    [Guid]
    $SubscriptionId,

    [parameter(Mandatory=$false)]
    [string]
    $ResourceGroupName = "RG_SPO_SITECREATIONEVENTQUEUE_PROD_EASTUS",

    [parameter(Mandatory=$false)]
    [string]
    $Location = "eastus"
)

Import-Module -Name "$PSScriptRoot\resources\resources.psm1" -Force -ErrorAction Stop

[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials 
[System.Net.ServicePointManager]::SecurityProtocol   = [System.Net.SecurityProtocolType]::Tls12   

$ctx = Get-AzContext

if( ($ctx.Tenant.Id -ne $TenantId.ToString() -or $ctx.Subscription.SubscriptionId -ne $SubscriptionId.ToString()) )
{
    Login-AzAccount -Tenant $TenantId -WarningAction SilentlyContinue
}

$null = Select-AzSubscription -Subscription $env:MSFT_SUBSCRIPTIONID -WarningAction SilentlyContinue | Out-Null

$templatePath  = Join-Path -Path $PSScriptRoot -ChildPath "resources\azure-deploy.bicep"
$parameterPath = Join-Path -Path $PSScriptRoot -ChildPath "resources\azure-deploy-parameters.$($Environment.ToLower()).json"

if( -not (Test-Path -Path $templatePath -PathType Leaf) )
{
    Write-Error "Template file not found at $templatePath."
    return
}

if( -not (Test-Path -Path $parameterPath -PathType Leaf) )
{
    Write-Error "Template parameter file not found at $parameterPath."
    return
}

# create resource group

    if( -not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue) )
    {
        Write-Host "[$(Get-Date)] - Provisioning Resource Group: $ResourceGroupName"
        $null = New-AzResourceGroup `
                -Name     $ResourceGroupName `
                -Location $Location `
                -Force `
                -ErrorAction Stop
    }


# start deployment

    Write-Host "[$(Get-Date)] - Starting deployment:"
    Write-Host "[$(Get-Date)] - `tTemplate Path:   $($templatePath)"
    Write-Host "[$(Get-Date)] - `tParameters Path: $($parameterPath)"

    $deployment = New-AzResourceGroupDeployment `
                        -ResourceGroupName     $ResourceGroupName `
                        -TemplateFile          $templatePath `
                        -TemplateParameterFile $parameterPath `
                        -ErrorAction Stop

    $deployment