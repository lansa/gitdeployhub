<#
.SYNOPSIS

Configure GitDeployHub for a single target LANSA environment

Presumed to be running from within the website that is being configured

.EXAMPLE

.\Install\Config.ps1 MyWebSite

#>

param (
    [Parameter(Mandatory=$true)]
        [string]
        $WebSiteName,

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

#Requires -RunAsAdministrator

# Check the execution policy allows LocalSystem user to execute scripts
Get-ExecutionPolicy -List
$ExecutionPolicy = Get-ExecutionPolicy -Scope MachinePolicy
if ( -not ($ExecutionPolicy -eq 'Unrestricted' -or $ExecutionPolicy -eq 'Bypass')) {
    $ExecutionPolicy = Get-ExecutionPolicy -Scope LocalMachine
    if ( -not ($ExecutionPolicy -eq 'Unrestricted' -or $ExecutionPolicy -eq 'Bypass')) {
        Write-Error ("ExecutionPolicy for MachinePolicy scope or LocalMachine scope need to be Unrestricted or Bypass in order for GitDeployHub scripts to be able to execute. Execute this on the command line  powershell Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine")
        throw
    }        
}

$MyInvocation.MyCommand.Path
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GitRepoRoot = Split-Path -Parent $ScriptDir
$WebSiteRootPath = Join-Path $GitRepoRoot 'web'
$Config = Join-Path $WebSiteRootPath 'web.config'

$doc = New-Object System.Xml.XmlDocument
$doc.Load($Config)

$Instance = $doc.SelectSingleNode('configuration/gitDeployHub/instances/instance[@name="' + $WebSiteName + '"]')

if ( $AddConfig) {
    if ( $Instance -eq $null ) {
        $Instance = $doc.configuration.gitDeployHub.instances.AppendChild($doc.CreateElement("instance"));
        $Instance.SetAttribute("name",$WebSiteName);
    }
    $Instance.SetAttribute("folder",$folder);
    $Instance.SetAttribute("projectFolder", "X_Win95\X_Lansa\X_Apps\$APPL");
    $Instance
} else {
    if ( $Instance -eq $null ) {
        Write-Error ("Instance $WebSiteName does not exist")
    } else {
        $Instance.ParentNode.RemoveChild($Instance)
    }
}
$doc.Save($Config)