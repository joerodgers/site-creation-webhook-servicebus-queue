<#

$parameters = @{
    "clientId"               = $env:O365_CLIENTID
    "tenantId"               = $env:O365_TENANTID
    "certificateThumbprint"  = $env:O365_THUMBPRINT
    "certificatePfxPassword" = $env:O365_CERT_PWD
    "certificatePfxBase64"   = [System.Convert]::ToBase64String(( Get-Content -Path "$PSScriptRoot\resources\certificate.pfx" -Raw -Encoding Byte ))
    "functionCode"           = (Get-Content -Path "$PSScriptRoot\resources\function.ps1" -Raw).ToString()
}

Set-DefaultParameterFileValue `
    -Path  "$PSScriptRoot\resources\azure-deploy-parameters.development.json" `
    -Value $parameters

#>