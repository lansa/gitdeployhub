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
        [String] 
        $Treeish,
           
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

    $MyInvocation.MyCommand.Path | Write-Host
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $GitRepoRoot = Split-Path -Parent $ScriptDir
    $WebSiteRootPath = Join-Path $GitRepoRoot 'web'
    $Config = Join-Path $WebSiteRootPath 'web.config'

    Write-Host("$(Log-Date)")

    Write-Host ("TargetSystem: $TargetSystem")
    Write-Host ("Folder: $folder")
    Write-Host ("APPL: $APPL")
    Write-Host ("Treeish: $Treeish")
    Write-Host ("AddConfig: $AddConfig")

   if ( [string]::IsNullOrEmpty($Treeish) ) {
      $Treeish = 'master'
      Write-Host ("Treeish is empty or null. defaulting to $Treeish")
   }

    $doc = New-Object System.Xml.XmlDocument
    $doc.Load($Config) | Write-Host

    $Instance = $doc.SelectSingleNode('configuration/gitDeployHub/instances/instance[@name="' + $TargetSystem + '"]')
    $Instances = $doc.SelectSingleNode('configuration/gitDeployHub/instances')

    if ( $AddConfig) {
        if ( $Instance -eq $null ) {
            $Instance = $Instances.AppendChild($doc.CreateElement("instance"));
            $Instance.SetAttribute("name",$TargetSystem) | Write-Host
        }
        $Instance.SetAttribute("folder",$folder) | Write-Host
        $Instance.SetAttribute("projectFolder", "X_Win95\X_Lansa\X_Apps\$APPL") | Write-Host
        $Instance.SetAttribute("treeish", $Treeish) | Write-Host
        $Instance | Write-Host
    } else {
        if ( $Instance -eq $null ) {
            Write-Error ("Instance $TargetSystem does not exist")
        } else {
            $Instance.ParentNode.RemoveChild($Instance) | Write-Host
        }
    }
    $doc.Save($Config) | Write-Host
} catch {
    $e = $_.Exception
    $e|format-list -force | Write-Host
    
    Write-Host("InstallConfigurationation failed")
    Write-Host("Raw LASTEXITCODE $LASTEXITCODE")  
    if ( (-not [string]::IsNullOrWhiteSpace($LASTEXITCODE)) -and ($LASTEXITCODE -ne 0)) {
        $ExitCode = $LASTEXITCODE
        Write-Host("ExitCode set to LASTEXITCODE $ExitCode")        
    } else {
        $ExitCode =  $e.HResult
        Write-Host("ExitCode set to HResult $ExitCode")        
    }

    if ( $ExitCode -eq $null -or $ExitCode -eq 0 ) {
        $ExitCode = -1
        Write-Host("ExitCode set to $ExitCode")        
    }
    Write-Host("Final ExitCode $ExitCode")
    cmd /c exit $ExitCode    #Set $LASTEXITCODE
    Write-Host("Final LASTEXITCODE $LASTEXITCODE")
    Write-Host("**************************")
    return    
} finally {
    Write-Host("$(Log-Date)")
}
Write-Host("Configuration succeeded")
cmd /c exit 0    #Set $LASTEXITCODE
Write-Host("LASTEXITCODE $LASTEXITCODE")
Write-Host("**************************")