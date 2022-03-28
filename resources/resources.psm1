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

function Format-Json
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [String]
        $json,

        [Parameter(Mandatory=$false)]
        [int]
        $NumberSpaces = 4
    ) 

    begin
    {
        $sb = New-Object System.Text.StringBuilder

        $indent = 0;
    }
    end
    {
        $lines =  $json -Split [System.Environment]::NewLine

        foreach( $line in $lines )
        {
            if( $line -match '[\}\]]' ) 
            {
                $indent--
            }
      
            $null = $sb.AppendFormat( "{0}{1}{2}", (' ' * $indent * $NumberSpaces), $line.TrimStart().Replace(':  ', ': '), [System.Environment]::NewLine )
             
            if ($line -match '[\{\[]')
            {
                $indent++
            }
        }

        $sb.ToString()
    }
}

function New-ArmTemplateParameterFile 
{
    [CmdletBinding()]
    param 
    (
        [parameter(Mandatory=$false)]
        [string] 
        $InputPath = (Join-Path $PSScriptRoot "azure-deploy.json"),
        
        [parameter(Mandatory=$false)]
        [string] 
        $OutputPath = (Join-Path $PSScriptRoot "azure-deploy-parameters.json"),

        [parameter(Mandatory=$false)]
        [switch] 
        $SkipOptionalParameters,

        [parameter(Mandatory=$false)]
        [ValidateSet("Production", "Test", "Development")]
        [string[]] 
        $Environment,

        [parameter(Mandatory=$false)]
        [switch] 
        $Force
    )
    begin
    {
        # shell object
        $parameterObject =  [PSCustomObject] @{
                                '$schema'      = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
                                contentVersion = "1.0.0.0"
                                parameters     = $null
                            }
    
        $defaultValue = [PSCustomObject] @{ value = "Prompt" }
    }
    process
    {

        # read in the template and convert to an object
        $template = Get-Content -Path $InputPath -Raw -ErrorAction Stop | ConvertFrom-Json
        
        $param = [PSCustomObject] @{}

        # get the parameters section
        foreach( $parameter in $template.parameters.psobject.members | Where-Object -Property "MemberType" -eq "NoteProperty" )
        {
            $isRequired = $null -eq ($parameter.value | Get-Member | Where-Object -Property "Name" -eq "defaultValue")

            if( $SkipOptionalParameters.IsPresent -and -not $isRequired )
            {
                continue
            }

            $param | Add-Member -MemberType NoteProperty -Name $parameter.Name -Value $defaultValue
        }

        $parameterObject.parameters = $param

        if( $PSBoundParameters.ContainsKey( "Environment" ) )
        {
            foreach( $env in $Environment )
            {
                $environmentOutputPath = $OutputPath -replace '.json', ".$env.json".ToLower()

                if( (Test-Path -Path $environmentOutputPath -PathType Leaf) -and -not $Force.IsPresent )
                {
                    Write-Error "Existing template found at $($OutputPath).  Use -Force to overwrite."
                    continue
                }

                $parameterObject | ConvertTo-Json -Depth 100 | Format-Json | Set-Content -Path $environmentOutputPath
            }

            return
        }

        if( (Test-Path -Path $OutputPath -PathType Leaf) -and -not $Force.IsPresent )
        {
            Write-Error "Existing template found at $($OutputPath).  Use -Force to overwrite."
            return
        }

        $parameterObject | ConvertTo-Json -Depth 100 | Format-Json | Set-Content -Path $OutputPath
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
        $parameters = Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json
        
        $members = $parameters.parameters.psobject.members | Where-Object -Property "MemberType" -eq "NoteProperty"

        foreach( $kv in $Value.GetEnumerator() )
        {
            if( $member = $members | Where-Object -Property "Name" -EQ $kv.key )
            {
                $parameters.parameters."$($kv.key )".value = $kv.value
            }
            else
            {
                Write-Warning "Parameter not found: $($v.key)"
            }
        }

        # $parameters | ConvertTo-Json -Depth 100 | Format-Json | Set-Content -Path $Path
        $parameters | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
    }
    end
    {
    }
}

function Get-ArmTemplateParameterFilePath
{
    [CmdletBinding()]
    param 
    (
        [parameter(Mandatory=$false)]
        [string] 
        $TemplatePath = (Join-Path -Path $PSScriptRoot -ChildPath "azure-deploy.json"),

        [parameter(Mandatory=$false)]
        [ValidateSet("Production", "Test", "Development")]
        [string[]] 
        $Environment
    )

    $fi = [System.IO.FileInfo]::new($TemplatePath)

    return "{0}\{1}-{2}{3}" -f $fi.Directory.FullName, $fi.BaseName, $Environment.ToLower(), $fi.Extension
}
