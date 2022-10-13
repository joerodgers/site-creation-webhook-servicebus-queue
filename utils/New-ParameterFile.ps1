param
(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Production", "Test", "Development")]
    [string]
    $Environment,

    [Parameter(Mandatory=$true)]
    [string]
    $EmailAddresses,

    [Parameter(Mandatory=$true)]
    [string]
    $MailboxAddress,

    [Parameter(Mandatory=$true)]
    [string]
    $EmailSubject,

    [Parameter(Mandatory=$true)]
    [string]
    $EmailTemplatePath,

    [Parameter(Mandatory=$true)]
    [string]
    $ProductionDate
)

Import-Module -Name "$PSScriptRoot\resources.psm1" -Force -ErrorAction Stop

# standard 1:1 parameters

    $parameters = @{}
    $parameters.EmailAddresses = $EmailAddresses
    $parameters.MailboxAddress = $MailboxAddress
    $parameters.EmailSubject   = $EmailSubject
    $parameters.ProductionDate = $ProductionDate

# read in email templates

    $parameters.EmailBody = (Get-Content -Path $EmailTemplatePath -Raw).psobject.BaseObject

New-ParameterFile `
    -OutputPath  "$PSScriptRoot\..\main.parameters.$Environment.json" `
    -Parameters $parameters `
    -Force

