<#
.SYNOPSIS

Configure GitDeployHub for a single target LANSA environment

Presumed to be running from within the website that is being configured

.EXAMPLE

.\Install\Config.ps1 MyTargetSystemName 'C:\Program Files (x86)\LANSA' DEMO $true

#>

param (
    [Parameter(Mandatory=$true)]
        [string]
        $TargetSystem,

    [Parameter(Mandatory=$true)]
        [String] 
        $folder,
        
    [Parameter(Mandatory=$true)]
        [String] 
        $APPL,
        
    [Parameter(Mandatory=$false)]
        [Boolean] 
        $AddConfig = $true
)

function Log-Date 
{
    ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ssZ")
}

cmd /c exit 0    #Set $LASTEXITCODE

try {
    #Requires -RunAsAdministrator

    $MyInvocation.MyCommand.Path
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $GitRepoRoot = Split-Path -Parent $ScriptDir
    $WebSiteRootPath = Join-Path $GitRepoRoot 'web'
    $Config = Join-Path $WebSiteRootPath 'web.config'

    Write-Output("$(Log-Date)")

    Write-Output ("TargetSystem: $TargetSystem")
    Write-Output ("Folder: $folder")
    Write-Output ("APPL: $APPL")
    Write-Output ("AddConfig: $AddConfig")

    $doc = New-Object System.Xml.XmlDocument
    $doc.Load($Config)

    $Instance = $doc.SelectSingleNode('configuration/gitDeployHub/instances/instance[@name="' + $TargetSystem + '"]')
    $Instances = $doc.SelectSingleNode('configuration/gitDeployHub/instances')

    if ( $AddConfig) {
        if ( $Instance -eq $null ) {
            $Instance = $Instances.AppendChild($doc.CreateElement("instance"));
            $Instance.SetAttribute("name",$TargetSystem);
        }
        $Instance.SetAttribute("folder",$folder);
        $Instance.SetAttribute("projectFolder", "X_Win95\X_Lansa\X_Apps\$APPL");
        $Instance
    } else {
        if ( $Instance -eq $null ) {
            Write-Error ("Instance $TargetSystem does not exist")
        } else {
            $Instance.ParentNode.RemoveChild($Instance)
        }
    }
    $doc.Save($Config)
} catch {
    $e = $_.Exception
    $e|format-list -force
    
    Write-Output("InstallConfigurationation failed")
    Write-Output("Raw LASTEXITCODE $LASTEXITCODE")  
    if ( (-not [string]::IsNullOrWhiteSpace($LASTEXITCODE)) -and ($LASTEXITCODE -ne 0)) {
        $ExitCode = $LASTEXITCODE
        Write-Output("ExitCode set to LASTEXITCODE $ExitCode")        
    } else {
        $ExitCode =  $e.HResult
        Write-Output("ExitCode set to HResult $ExitCode")        
    }

    if ( $ExitCode -eq $null -or $ExitCode -eq 0 ) {
        $ExitCode = -1
        Write-Output("ExitCode set to $ExitCode")        
    }
    Write-Output("Final ExitCode $ExitCode")
    cmd /c exit $ExitCode    #Set $LASTEXITCODE
    Write-Output("Final LASTEXITCODE $LASTEXITCODE")
    Write-Output("**************************")
    return    
} finally {
    Write-Output("$(Log-Date)")
}
Write-Output("Configuration succeeded")
cmd /c exit 0    #Set $LASTEXITCODE
Write-Output("LASTEXITCODE $LASTEXITCODE")
Write-Output("**************************")