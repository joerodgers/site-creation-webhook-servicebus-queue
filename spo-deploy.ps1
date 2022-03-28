#requires -modules "PnP.PowerShell"

param
(
    [parameter(Mandatory=$true)]
    [string]
    $Tenant,

    [parameter(Mandatory=$true)]
    [Guid]
    $ClientId,

    [parameter(Mandatory=$true)]
    [string]
    $Thumbprint,

    [parameter(Mandatory=$true)]
    [Uri]
    $WebHookUrl,

    [parameter(Mandatory=$true)]
    [Guid]
    $PrincipalObjectId,

    [parameter(Mandatory=$false)]
    [switch]
    $Force
)

[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials 
[System.Net.ServicePointManager]::SecurityProtocol   = [System.Net.SecurityProtocolType]::Tls12   

Connect-PnPOnline `
    -Url        "https://$Tenant-admin.sharepoint.com" `
    -ClientId   $ClientId `
    -Thumbprint $Thumbprint `
    -Tenant     "$Tenant.onmicrosoft.com" `
    -ErrorAction Stop

if( -not $? ){ return }


# create template schema

    $templateSchema = '
                {{
                "$schema" : "schema.json",
                "actions" : [
                    {{
                    "verb" : "triggerFlow",
                    "url"  : "{0}",
                    "name" : "Execute Webhook",
                    "parameters" : {{
                        "event"    : "Site Creation",
                        "product"  : "SharePoint Online",
                        "template" : "{1}"
                    }}
                    }}
                ]
                }}
                '

                

# create the site script and site template

    $templates = @( [PSCustomObject] @{ Template = "TeamSite";          TemplateId = 64 }
                    [PSCustomObject] @{ Template = "ChannelSite";       TemplateId = 69 }
                    [PSCustomObject] @{ Template = "CommunicationSite"; TemplateId = 68 }
                    [PSCustomObject] @{ Template = "GrouplessTeamSite"; TemplateId = 1  }
                  )

    foreach( $template in $templates )
    {
        $siteDesign = Get-PnPSiteDesign -ErrorAction Stop | Where-Object -Property "Title" -eq "$($template.Template) Creation Webhook"
        $siteScript = Get-PnPSiteScript -ErrorAction Stop | Where-Object -Property "Title" -eq "$($template.Template) Creation Webhook"
        
        if( ($default = Get-PnPSiteDesign -ErrorAction Stop | Where-Object -FilterScript { $_.WebTemplate -eq $template.TemplateId -and $_.IsDefault }) -and -not $Force.IsPresent )
        {
            Write-Warning "Skipping $($template.Template), a template with title '$($default.Title)' is already regiested as the default template for web template $($template.TemplateId).  Use -Force to overwrite the default template."
            continue
        }

        if( $Force.IsPresent -and $siteDesign )
        {
            $siteDesign | Remove-PnPSiteDesign -Force -ErrorAction Stop
            $siteDesign = $null
        }
        
        if( $Force.IsPresent -and $siteScript )
        {
            $siteScript | Remove-PnPSiteScript -Force -ErrorAction Stop
            $siteScript = $null
        }

        if( -not $siteScript )
        {
            Write-Host "Provisioning Site Script: $($template.Template) Creation Webhook"
    
            $schema = $templateSchema -f $WebHookUrl, $template.Template

            $siteScript = Add-PnPSiteScript `
                                -Title       "$($template.Template) Creation Webhook"  `
                                -Description "Executes a webhook for all $($template.Template) template based sites." `
                                -Content     $schema `
                                -ErrorAction Stop
        }
        
        if( -not $siteDesign -and $siteScript )
        {
            Write-Host "Provisioning Site Design: $($template.Template) Creation Webhook"

            $design = Add-PnPSiteDesign `
                            -Title          "$($template.Template) Creation Webhook"  `
                            -Description    "Executes a webhook for all $($template.Template) template based sites." `
                            -SiteScriptIds  $siteScript.Id `
                            -WebTemplate    $template.Template `
                            -IsDefault `
                            -ErrorAction Stop

            Grant-PnPSiteDesignRights `
                -Identity $design.Id `
                -Principals "c:0t.c|tenant|$PrincipalObjectId" `
                -Rights View `
                -ErrorAction Stop
        }
    }
