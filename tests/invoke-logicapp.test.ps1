
$url = "https://prod-25.eastus.logic.azure.com:443/workflows/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

$templates = "GROUP", "STS", "SITEPAGEPUBLISHING", "TEAMCHANNEL" | ForEach-Object {

    $template = $_

    @{
        createdTimeUTC = [DateTime]::UtcNow
        creatorEmail   = "john.doe@contoso.com"
        creatorName    = "John Doe"
        groupId        = "2b0ebd4a-639b-473e-bef5-1b3f055add20"
        parameters     = @{ template = $template }
        webDescription = "Testing Site Description"
        webTitle       = "Testing Site Title"
        webUrl         = "https://contoso.sharepoint.com/sites/testing"
    }
}

foreach( $template in $templates )
{
    Write-Host "Sending Test Message for Template: $($template.parameters.template)"
    
    $body = $template | ConvertTo-Json

    $null = Invoke-RestMethod `
                -Method      Post `
                -Uri         $url `
                -Body        $body `
                -ContentType "application/json" `
                -ErrorAction Stop
}

