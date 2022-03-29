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

[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials 
[System.Net.ServicePointManager]::SecurityProtocol   = [System.Net.SecurityProtocolType]::Tls12   

$ctx = Get-AzContext

if( $ctx.Tenant.Id -ne $TenantId.ToString() -or $ctx.Subscription.SubscriptionId -ne $SubscriptionId.ToString() )
{
    Write-Host "[$(Get-Date)] - Prompting for Azure credentials"
    Login-AzAccount -Tenant $TenantId -WarningAction SilentlyContinue

    $ctx = Get-AzContext
}

$subscription = Select-AzSubscription -Subscription $SubscriptionId -WarningAction SilentlyContinue

Write-Host "[$(Get-Date)] - Connected as: $($ctx.Account.Id)"
Write-Host "[$(Get-Date)] - Subscription: $($subscription.Subscription.Name)"

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