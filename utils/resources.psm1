function Show-OAuthWindow
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$true)]
        [System.Uri]
        $Url
    )

    begin
    {
        Add-Type -AssemblyName System.Windows.Forms
    }
    process 
    {
        $web = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{
            Width  = 420
            Height = 600
            Url    = $Url
        }
    
        $web.ScriptErrorsSuppressed = $true
    
        $web.Add_DocumentCompleted( {
                if ($web.Url.AbsoluteUri -match "error=[^&]*|code=[^&]*") { $form.Close() }
            })

        $form = New-Object -TypeName System.Windows.Forms.Form -Property @{
            Width  = 440
            Height = 640
        }
    
        $form.Controls.Add($web)
    
        $form.Add_Shown( {
                $form.BringToFront()
                $null = $form.Focus()
                $form.Activate()
                $web.Navigate($Url)
            })

        $null = $form.ShowDialog()

        $queryOutput = [System.Web.HttpUtility]::ParseQueryString($web.Url.Query)
        
        $output = @{}
        
        foreach ($key in $queryOutput.Keys) 
        {
            $output["$key"] = $queryOutput[$key]
        }

        [pscustomobject]$output
    }
}

function New-ParameterFile 
{
    [CmdletBinding()]
    param 
    (
        [parameter(Mandatory=$false)]
        [string] 
        $OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath "main.parameters.$Environment.json"),

        [parameter(Mandatory=$false)]
        [ValidateSet("Production", "Test", "Development")]
        [string[]] 
        $Environment,

        [parameter(Mandatory=$false)]
        [HashTable] 
        $Parameters,

        [parameter(Mandatory=$false)]
        [switch] 
        $Force
    )
    begin
    {
        $parameterObject =  [PSCustomObject] @{
            '$schema'      = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
            contentVersion = "1.0.0.0"
            parameters     = @()
        }
    }
    process
    {
        foreach( $parameter in $Parameters.GetEnumerator() )
        {
            $parameterObject.parameters += @{ $parameter.Key = @{ value = $parameter.Value } }
        }
       
        if( (Test-Path -Path $OutputPath -PathType Leaf) -and -not $Force.IsPresent )
        {
            Write-Error "Existing template found at $($OutputPath).  Use -Force to overwrite."
            return
        }

        $parameterObject | ConvertTo-Json | Out-String | Set-Content -Path $OutputPath
    }
    end
    {
    }
}

function Set-DefaultParameterFileValue
{
    [CmdletBinding()]
    param 
    (
        [parameter(Mandatory=$false)]
        [string] 
        $Path,
        
        [parameter(Mandatory=$true)]
        [HashTable] 
        $Value
    )

    begin
    {
    }
    process
    {
        # read in the template and convert to an object
        $parameters = (Get-Content -Path $Path -Raw -ErrorAction Stop).psobject.BaseObject | ConvertFrom-Json
        
        $members = $parameters.parameters.psobject.members | Where-Object -Property "MemberType" -eq "NoteProperty"

        foreach( $kv in $Value.GetEnumerator() )
        {
            if( $members | Where-Object -Property "Name" -EQ $kv.key )
            {
                $parameters.parameters."$($kv.key )".value = $kv.value
            }
            else
            {
                Write-Warning "Parameter not found: $($v.key)"
            }
        }

        $parameters | ConvertTo-Json | Out-String | Set-Content -Path $Path
    }
    end
    {
    }
}

function Convert-CertificateToBase64String
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Need plaintext password for .NET API')]
    [CmdletBinding()]
    param 
    (
        [parameter(Mandatory=$true)]
        [string]    
        $Path,
        
        [parameter(Mandatory=$true,ParameterSetName='RemovePasswordProtection')]
        [string] 
        $Password,

        [parameter(Mandatory=$true,ParameterSetName='RemovePasswordProtection')]
        [switch] 
        $RemovePasswordProtection
    )
    process
    {
        if( -not (Test-Path -Path $Path -PathType Leaf) )
        {
            Write-Error "File not found: $Path"
            return
        }

        if( $PSCmdlet.ParameterSetName -ne "RemovePasswordProtection" )
        {
            $bytes = Get-Content -Path $Path -Encoding Byte 
            return [System.Convert]::ToBase64String($bytes) 
        }

        $collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        
        $collection.Import( $Path, $Password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable )
        
        if ( $RemovePasswordProtection.IsPresent )
        {
            $bytes = $collection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12)
        }
        else 
        {
            $bytes = $collection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $Password)
        }
        
        return [System.Convert]::ToBase64String($bytes) 
   }
}

