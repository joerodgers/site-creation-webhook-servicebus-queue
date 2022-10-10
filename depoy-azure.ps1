#requires -modules "Az.Resources", "Az.Accounts"

param
(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Production", "Test", "Development")]
    [string]
    $Environment = "Development",

    [Parameter(Mandatory=$true)]
    [Guid]
    $TenantId,

    [Parameter(Mandatory=$true)]
    [Guid]
    $SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string]
    $ResourceGroup,

    [Parameter(Mandatory=$false)]
    [string]
    $Location = "eastus"
)

Import-Module -Name .\utils\resources.psm1 -Force -ErrorAction Stop

[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials 
[System.Net.ServicePointManager]::SecurityProtocol   = [System.Net.SecurityProtocolType]::Tls12   

$ctx = Get-AzContext

if( $ctx.Tenant.Id -ne $TenantId.ToString() -or $ctx.Subscription.SubscriptionId -ne $SubscriptionId.ToString() )
{
    Write-Host "[$(Get-Date)] - Prompting for Azure credentials"
    Login-AzAccount -Tenant $TenantId -WarningAction SilentlyContinue

    $ctx = Get-AzContext
}


$subscription = Select-AzSubscription -SubscriptionId $SubscriptionId -Tenant $TenantId -WarningAction SilentlyContinue -Force

Write-Host ""
Write-Host "[$(Get-Date)] - Connected as: $($ctx.Account.Id)"
Write-Host "[$(Get-Date)] - Subscription: $($subscription.Subscription.Name)"
Write-Host "[$(Get-Date)] - Environment:  $Environment"

$templatePath  = Join-Path -Path $PSScriptRoot -ChildPath "main.bicep"
$parameterPath = Join-Path -Path $PSScriptRoot -ChildPath "main.parameters.$Environment.json"

# path validation

    foreach( $path in @($templatePath, $parameterPath ) )
    {
        if( -not (Test-Path -Path $path -PathType Leaf) )
        {
            Write-Error "Required file not found: $path"
            return
        }
    }

    if( -not (Test-Path -Path "$PSScriptRoot\deploymentlogs" -PathType Container) )
    {
        New-Item -ItemType Directory -Path "$PSScriptRoot\deploymentlogs"
    }

    Write-Host ""
    Write-Host "[$(Get-Date)] - Template Path:     $templatePath"
    Write-Host "[$(Get-Date)] - Parameter Path:    $parameterPath"
    Write-Host "[$(Get-Date)] - Log Path:          $PSScriptRoot\deploymentlogs"

# resource group validation

    if( -not (Get-AzResourceGroup -Name $ResourceGroup -Location $Location -ErrorAction SilentlyContinue) )
    {
        Write-Error "Resource group not found: $ResourceGroup"
        return
    }


# start deployment
    Write-Host 
    Write-Host "[$(Get-Date)] - Starting deployment"
    
    $deployment = New-AzResourceGroupDeployment `
                        -ResourceGroupName     $ResourceGroup `
                        -TemplateFile          $templatePath `
                        -TemplateParameterFile $parameterPath -Verbose

    Write-Host "[$(Get-Date)] - Deployment $($deployment.ProvisioningState)"

    if( $deployment.OutputsString )
    {
        $deployment.OutputsString | Set-Content -Path "$PSScriptRoot\deploymentlogs\deploymentoutput_$(Get-Date -Format FileDateTime).log"
    }

    if( $deployment.ProvisioningState -ne "Succeeded" ) { return }


# authorize api connections

    Write-Host "[$(Get-Date)] - Authorizing API Connections"

    $connections = Get-AzResource -ResourceType "Microsoft.Web/connections" -ResourceGroupName $resourceGroup 

    foreach( $connection in $connections )
    {
        $connection = Get-AzResource -ResourceId $connection.ResourceId

        if( $connection.Properties.overallStatus -notmatch "Connected|Ready" )
        {
            Write-Host "[$(Get-Date)] - Authorizing Connection: $($connection.Name)"

            $parameters = @{
                "parameters" = ,@{
                    "parameterName" = "token";
                    "redirectUrl"   = "https://ema1.exp.azure.com/ema/default/authredirect"
                }
            }

            $consentLink = Invoke-AzResourceAction `
                                    -Action    "listConsentLinks" `
                                    -ResourceId $connection.ResourceId `
                                    -Parameters $parameters `
                                    -Force   
            
            if( $null -eq $consentLink -or [string]::IsNullOrWhiteSpace($consentLink.value.link) )
            {
                Write-Warning "Connection $($connection.Name) has not consent link."
                continue
            }

            $consentCode = Show-OAuthWindow -Url $consentLink.value.link
        
            try
            {
                Invoke-AzResourceAction `
                        -Action      "confirmConsentCode" `
                        -ResourceId  $connection.ResourceId `
                        -Parameters  @{ code = $consentCode.code } `
                        -Force `
                        -ErrorAction Stop
            }
            catch
            {
                # throws the following error due to lack of response:
                # Cannot process argument because the value of argument "obj" is null. Change the value of argument "obj" to a non-null value
                if( $_ -notmatch 'Cannot process argument because the value of argument "obj" is null' )
                {
                    throw "HERE: $_"
                }
            }
        }
    }

    $connections = Get-AzResource -ResourceType "Microsoft.Web/connections" -ResourceGroupName $resourceGroup 

    foreach( $connection in $connections )
    {
        $conn = Get-AzResource -ResourceId $connection.ResourceId

        Write-Host "[$(Get-Date)] - `tConnection $($conn.Name): $($conn.Properties.statuses[0].status)"
    }
